from __future__ import annotations

import asyncio
import ast
import gzip
import io
from pathlib import Path
import shlex
import tempfile
import tomllib
from types import SimpleNamespace
from types import ModuleType
import unittest
from unittest.mock import AsyncMock
from unittest.mock import patch
import re
import sys

from hostlib.config import QemuConfig, RetroConfig, load_config, load_qemu_config
from hostlib.context import Context
from hostlib.errors import CommandError, ConfigError, RetroError
from hostlib import cli, download, operations, qmp_cli, slackware
from hostlib.fdisk import Fdisk
from hostlib.keyboard import encode
from hostlib.dialog import Choice, Dialog
from hostlib.session import InstallSession, Match
from hostlib.serial import SerialConsole
from hostlib.installers.slackware import Pkgtool, PkgtoolOptions, boot_pkgtool
from hostlib.installers.debian import Dinstall, DinstallOptions
from hostlib.installers.slackware_early import Sysinstall, SysinstallOptions
from hostlib.installers import (
    DRIVERS,
    STEP_ACTIONS,
    run_configured_install,
    validate_install_config,
)
from hostlib import installers
from hostlib.installers import redhat, redhat_early
from hostlib.vga import Screen, ScreenObserver, decode
from hostlib.media import MediaStager, toml_extraction
from hostlib.qmp import Monitor
from hostlib.qemu import QemuRuntime


def temporary_config(
    root: Path, name: str, data: dict | None = None
) -> tuple[Context, RetroConfig]:
    """Create a minimal config and context beneath a temporary repository."""
    directory = root / name
    directory.mkdir(parents=True)
    context = Context(root, directory, "boot", root / "temporary")
    context.temporary.mkdir(exist_ok=True)
    return context, RetroConfig(context, data or {})


class ContextTests(unittest.TestCase):
    def test_find_prefers_selected_config_then_parent(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = root / "distro" / "version"
            config.mkdir(parents=True)
            (config.parent / "shared").write_text("parent")
            context = Context.create(root, "help", str(config))
            self.assertEqual(context.find("shared"), (config.parent / "shared").resolve())
            (config / "shared").write_text("local")
            self.assertEqual(context.find("shared"), (config / "shared").resolve())


class CommandNameTests(unittest.TestCase):
    def test_python_owns_canonical_names_and_shell_commands_are_namespaced(self) -> None:
        root = Path(__file__).resolve().parent.parent
        project = tomllib.loads((root / "pyproject.toml").read_text())
        self.assertEqual(
            project["project"]["scripts"],
            {"retro": "hostlib.cli:main", "qmp": "hostlib.qmp_cli:main"},
        )
        self.assertIn("from hostlib.cli import main", (root / "retro").read_text())
        self.assertIn("from hostlib.qmp_cli import main", (root / "qmp").read_text())
        self.assertTrue((root / "retro-bash").is_file())
        self.assertTrue((root / "qmp-bash").is_file())

    def test_prerequisites_are_owned_by_the_standalone_shell_script(self) -> None:
        root = Path(__file__).resolve().parent.parent
        bootstrap = root / "retro-prereq"
        self.assertTrue(bootstrap.is_file())
        self.assertTrue(bootstrap.stat().st_mode & 0o111)
        self.assertNotIn("prereq", cli.COMMANDS)
        self.assertFalse(hasattr(operations, "install_prerequisites"))


class CliTests(unittest.TestCase):
    def test_extract_downloads_before_staging(self) -> None:
        context = SimpleNamespace(command="extract")
        config = SimpleNamespace()
        calls: list[str] = []
        with (
            patch.object(cli, "Downloader") as downloader,
            patch.object(cli, "MediaStager") as stager,
        ):
            downloader.return_value.run.side_effect = lambda: calls.append("download")
            stager.return_value.extract.side_effect = lambda: calls.append("extract")
            cli.Application(context, config).run()
        self.assertEqual(calls, ["download", "extract"])

    def test_install_validates_before_download_and_vm_start(self) -> None:
        context = SimpleNamespace(command="install")
        config = SimpleNamespace()
        with (
            patch.object(cli, "load_qemu_config", return_value=QemuConfig()),
            patch.object(cli, "validate_install_config") as validate,
            patch.object(cli, "Downloader") as downloader,
            patch.object(cli, "MediaStager") as stager,
            patch.object(cli.asyncio, "run") as run,
            patch.object(cli.Application, "_run_vm", new=unittest.mock.Mock(return_value="vm")),
        ):
            cli.Application(context, config).run()
        validate.assert_called_once_with(config)
        downloader.return_value.run.assert_called_once_with()
        stager.return_value.extract.assert_called_once_with()
        run.assert_called_once()

    def test_reset_requires_an_affirmative_answer(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            context, config = temporary_config(root, "distro/version")
            context.qemu_dir.mkdir()
            with patch("builtins.input", return_value="no"):
                cli.Application(context, config).reset()
            self.assertTrue(context.qemu_dir.exists())
            with patch("builtins.input", return_value="yes"):
                cli.Application(context, config).reset()
            self.assertFalse(context.qemu_dir.exists())

    def test_run_main_always_removes_the_context_temporary_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            scratch = Path(temporary) / "command-temp"
            scratch.mkdir()
            context = SimpleNamespace(
                command="help", name="test", temporary=scratch, config=Path(temporary)
            )
            with (
                patch.object(cli.Context, "create", return_value=context),
                patch.object(cli, "load_config", return_value=SimpleNamespace()),
                patch.object(cli.Application, "run", side_effect=ConfigError("broken")),
            ):
                with self.assertRaisesRegex(ConfigError, "broken"):
                    cli.run_main(["help"])
            self.assertFalse(scratch.exists())

    def test_vm_failure_closes_monitor_and_terminates_process(self) -> None:
        process = SimpleNamespace(
            returncode=None,
            wait=AsyncMock(return_value=0),
            terminate=unittest.mock.Mock(),
        )
        monitor = SimpleNamespace(close=AsyncMock())
        runtime = SimpleNamespace(
            start=AsyncMock(return_value=process),
            connect_monitor=AsyncMock(return_value=monitor),
        )
        app = cli.Application(SimpleNamespace(qemu_dir=Path("qemu.d")), SimpleNamespace())
        with (
            patch.object(cli, "QemuRuntime", return_value=runtime),
            patch.object(cli, "run_install", AsyncMock(side_effect=RetroError("install failed"))),
        ):
            with self.assertRaisesRegex(RetroError, "install failed"):
                asyncio.run(app._run_vm(QemuConfig(), install=True))
        monitor.close.assert_awaited_once_with()
        process.terminate.assert_called_once_with()
        process.wait.assert_awaited_once_with()


class DownloadTests(unittest.TestCase):
    def test_direct_download_creates_nested_path_and_skips_existing_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            context, config = temporary_config(
                root,
                "distro/version",
                {"download": {"files": [{"path": "nested/disk.img", "url": "https://x"}]}},
            )
            filesystem = unittest.mock.Mock()

            def retrieve(_url, path, callback):
                Path(path).write_bytes(b"media")
                callback.set_size(5)
                callback.relative_update(5)

            filesystem.get_file.side_effect = retrieve
            Download = download.Downloader(context, config)
            Download._http = filesystem
            Download.run()
            Download.run()
            self.assertEqual((config.download_dir / "nested/disk.img").read_bytes(), b"media")
            self.assertEqual(
                filesystem.get_file.call_args.args,
                ("https://x", str(config.download_dir / "nested/disk.img")),
            )
            self.assertIsInstance(
                filesystem.get_file.call_args.kwargs["callback"], download.DownloadProgress
            )

    def test_download_rejects_unsafe_paths_and_invalid_entries(self) -> None:
        context = SimpleNamespace()
        for files, message in (
            ([{"path": "../disk.img", "url": "https://x"}], "Unsafe"),
            ([{"path": "disk.img"}], "Missing URL"),
            ("disk.img", "array of tables"),
        ):
            config = RetroConfig(context, {"download": {"files": files}})
            with self.assertRaisesRegex(ConfigError, message):
                if isinstance(files, list) and files and "url" in files[0]:
                    download.Downloader(context, config)._download(config, Path("unused"))
                else:
                    download.Downloader._validate(config)

    def test_cdrom_download_links_shared_iso_into_selected_qemu_state(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shared = root / "cdrom/shared"
            shared.mkdir(parents=True)
            (shared / "config.toml").write_text(
                '[[download.files]]\npath = "disc.iso"\nurl = "https://x"\n'
            )
            context, config = temporary_config(
                root, "distro/version", {"download": {"cdrom": "shared"}}
            )
            filesystem = unittest.mock.Mock()
            filesystem.get_file.side_effect = lambda _url, path, callback: Path(path).write_bytes(
                b"iso"
            )
            downloader = download.Downloader(context, config)
            downloader._http = filesystem
            downloader.run()
            linked = context.qemu_dir / "disc.iso"
            self.assertTrue(linked.is_symlink())
            self.assertEqual(linked.read_bytes(), b"iso")

    def test_recursive_listing_failure_is_reported(self) -> None:
        downloader = download.Downloader(SimpleNamespace(), SimpleNamespace())
        downloader._http = unittest.mock.Mock()
        downloader._http.ls.side_effect = RuntimeError("network failed")
        with self.assertRaisesRegex(OSError, "Could not list HTTP directory"):
            downloader._mirror_tree("https://x/tree/", Path("out"))

    def test_recursive_mirror_rejects_paths_outside_its_remote_root(self) -> None:
        downloader = download.Downloader(SimpleNamespace(), SimpleNamespace())
        downloader._http = unittest.mock.Mock()
        for remote in (
            "https://x/tree/../escape/",
            "https://x/tree/%2e%2e/escape/",
            "https://other/tree/escape/",
        ):
            with self.subTest(remote=remote):
                downloader._http.reset_mock()
                downloader._http.ls.return_value = [{"name": remote, "type": "directory"}]
                with self.assertRaisesRegex(ConfigError, "escapes mirror root"):
                    downloader._mirror_tree("https://x/tree/", Path("out"))
                downloader._http.ls.assert_called_once_with("https://x/tree/", detail=True)
                downloader._http.get_file.assert_not_called()

    def test_mirror_release_names_cannot_escape_the_download_directory(self) -> None:
        downloader = download.Downloader(SimpleNamespace(), SimpleNamespace())
        for method in (downloader._debian, downloader._slackware):
            with self.subTest(method=method.__name__):
                with self.assertRaisesRegex(ConfigError, "unsafe release name"):
                    method("../escape", Path("download.d"))

    def test_recursive_mirror_preserves_layout_filters_and_progress(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "release"
            destination.mkdir()
            (destination / "disk1").write_text("stale directory index")
            filesystem = unittest.mock.Mock()
            events = []

            def listing(url, *, detail):
                events.append(("list", url))
                return {
                    "https://x/tree/": [
                        {"name": "https://x/tree/disk1", "type": "file"},
                        {"name": "https://x/tree/disk1/", "type": "directory"},
                        {"name": "https://x/tree/sub%20dir/", "type": "directory"},
                    ],
                    "https://x/tree/disk1/": [
                        {"name": "https://x/tree/disk1/package.tgz", "type": "file"},
                        {"name": "https://x/tree/disk1/package.md5", "type": "file"},
                        {"name": "https://x/tree/disk1/?C=N;O=D", "type": "file"},
                    ],
                    "https://x/tree/sub%20dir/": [
                        {"name": "https://x/tree/sub%20dir/readme.txt", "type": "file"},
                        {
                            "name": "https://x/tree/sub%20dir/MAILTO:cae@best.com",
                            "type": "file",
                        },
                    ],
                }[url]

            def retrieve(url, path, callback):
                events.append(("download", url))
                Path(path).write_text("downloaded")

            filesystem.ls.side_effect = listing
            filesystem.get_file.side_effect = retrieve
            downloader = download.Downloader(SimpleNamespace(), SimpleNamespace())
            downloader._http = filesystem
            downloader._mirror_tree("https://x/tree/", destination, reject=("*.md5",))
            self.assertTrue((destination / "disk1/package.tgz").is_file())
            self.assertFalse((destination / "disk1/package.md5").exists())
            self.assertTrue((destination / "sub dir/readme.txt").is_file())
            self.assertEqual(filesystem.get_file.call_count, 2)
            self.assertNotIn(("download", "https://x/tree/disk1"), events)
            self.assertNotIn(
                ("download", "https://x/tree/sub%20dir/MAILTO:cae@best.com"),
                events,
            )
            self.assertLess(
                events.index(("download", "https://x/tree/disk1/package.tgz")),
                events.index(("list", "https://x/tree/sub%20dir/")),
            )

    def test_progress_bar_reports_known_and_unknown_transfer_sizes(self) -> None:
        class Terminal(io.StringIO):
            def isatty(self) -> bool:
                return True

        stream = Terminal()
        progress = download.DownloadProgress("disk.img", stream=stream, width=10)
        progress.set_size(1024)
        progress.relative_update(512)
        progress.relative_update(512)
        progress.close()
        output = stream.getvalue()
        self.assertIn("[#####-----]  50.0%", output)
        self.assertIn("[##########] 100.0%", output)
        self.assertTrue(output.endswith("\n"))

        stream = Terminal()
        progress = download.DownloadProgress("disk.img", stream=stream, width=10)
        progress.set_size(None)
        progress.relative_update(2048)
        progress.close()
        self.assertIn("2.0 KiB", stream.getvalue())

    def test_progress_bar_is_silent_when_output_is_redirected(self) -> None:
        stream = io.StringIO()
        progress = download.DownloadProgress("disk.img", stream=stream)
        progress.set_size(2048)
        progress.relative_update(1024)
        progress.close()
        self.assertEqual(stream.getvalue(), "")

    def test_progress_bar_fits_in_80_columns_with_four_digit_sizes(self) -> None:
        class Terminal(io.StringIO):
            def isatty(self) -> bool:
                return True

        stream = Terminal()
        size = 9999 * 1024**3
        progress = download.DownloadProgress("a-very-long-installation-image-filename.iso", stream)
        progress.set_size(size)
        progress.relative_update(size)
        progress.close()
        line = stream.getvalue().split("\r")[-1].rstrip("\n")
        self.assertEqual(len(line), 80)
        self.assertIn("...", line)
        self.assertTrue(line.endswith("9999 GiB/9999 GiB"))


class OperationsTests(unittest.TestCase):
    def test_package_writes_both_launchers_and_archive(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            context, config = temporary_config(
                root, "distro/version", {"qemu": {"profile": "default"}}
            )
            runtime = unittest.mock.Mock()
            runtime.command.return_value = ["qemu-system-i386", "-name", "two words"]
            with (
                patch.object(operations, "QemuRuntime", return_value=runtime),
                patch.object(operations.Path, "cwd", return_value=root),
            ):
                archive = operations.package(context, config)
            runtime.ensure_disk.assert_called_once_with()
            self.assertIn("'two words'", (context.qemu_dir / "retro.sh").read_text())
            self.assertIn('"two words"', (context.qemu_dir / "retro.bat").read_text())
            self.assertTrue(archive.is_file())


class QmpCliTests(unittest.IsolatedAsyncioTestCase):
    async def test_socket_resolution_and_control_commands(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            explicit = root / "custom.sock"
            self.assertEqual(qmp_cli._socket(explicit), explicit)
            monitor = AsyncMock()

            class MonitorContext:
                async def __aenter__(self):
                    return monitor

                async def __aexit__(self, *_):
                    return None

            with patch.object(qmp_cli, "Monitor", return_value=MonitorContext()):
                await qmp_cli._run(["change-image", "-s", str(explicit), "root.img"])
                await qmp_cli._run(["eject-disk", "-s", str(explicit), "floppy1"])
                await qmp_cli._run(["send-text", "-s", str(explicit), "-n", "Ab"])
            self.assertEqual(
                [call.args[0] for call in monitor.hmp.await_args_list],
                ["change floppy0 root.img raw", "eject floppy1"],
            )
            self.assertEqual(
                [call.args[0] for call in monitor.send_key.await_args_list],
                ["shift-a", "b", "ret"],
            )

    async def test_send_stdin_encodes_all_input(self) -> None:
        monitor = AsyncMock()

        class MonitorContext:
            async def __aenter__(self):
                return monitor

            async def __aexit__(self, *_):
                return None

        with (
            patch.object(qmp_cli, "Monitor", return_value=MonitorContext()),
            patch.object(qmp_cli.sys, "stdin", io.StringIO("ok\n")),
        ):
            await qmp_cli._run(["send-stdin", "-s", "qmp.sock"])
        self.assertEqual(
            [call.args[0] for call in monitor.send_key.await_args_list], ["o", "k", "ret"]
        )


class SlackwareTagfileTests(unittest.TestCase):
    def test_package_names_remove_only_slackware_version_suffixes(self) -> None:
        self.assertEqual(slackware._package_name("bash-1.14.7-i386-1.tgz"), "bash")
        self.assertEqual(slackware._package_name("kernel.tgz"), "kernel")

    def test_prepare_tagfiles_applies_exact_rules_over_series_defaults(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            context, _ = temporary_config(root, "slackware/3.0/walnut")
            (context.config / "full.tag").write_text("a * SKP\na bash ADD\n")
            qemu = context.qemu_dir
            packages = qemu / "fat/packages/a1"
            packages.mkdir(parents=True)
            (packages / "bash-1.0-i386-1.tgz").touch()
            (packages / "ed-1.0-i386-1.tgz").touch()
            slackware.prepare_tagfiles(context, qemu, context.config / "download.d")
            tagfile = packages / "tagfile"
            self.assertEqual(tagfile.read_text(), "bash:     ADD\ned:     SKP\n")
            self.assertEqual((qemu / "fat/disksets.txt").read_text(), "a\n")

    def test_generate_default_tag_combines_installer_tags_and_descriptions(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            context, _ = temporary_config(root, "slackware/3.0/walnut")
            source = context.qemu_dir / "fat/install/a1"
            source.mkdir(parents=True)
            (source / "tagfile").write_text("bash: ADD\ned: OPT\n")
            (source / "disk1").write_text("bash: Bourne Again Shell\n")
            slackware.generate_default_tag(context, context.qemu_dir)
            generated = (context.config / "default.tag").read_text()
            self.assertIn("a    *            SKP", generated)
            self.assertIn("bash", generated)
            self.assertIn("# Bourne Again Shell", generated)


class ConfigTests(unittest.TestCase):
    def test_profile_only_fills_unspecified_values(self) -> None:
        config = QemuConfig(profile="linux-2.0", ram="32M")
        config.apply_profile()
        self.assertEqual(config.ram, "32M")
        self.assertEqual(config.disk_size, "8G")
        self.assertEqual(config.vga, "cirrus")

    def test_toml_inherits_parent_tables_and_replaces_arrays(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            parent = root / "slackware/3.0"
            child = parent / "walnut"
            child.mkdir(parents=True)
            (parent / "config.toml").write_text(
                '[qemu]\nprofile = "linux-1.2"\n'
                '[qemu.network]\ndevice = "ne2k_isa"\n'
                '[postinst]\nstages = ["tty", "x11"]\n'
            )
            (child / "config.toml").write_text(
                '[qemu.network]\ndevice = "pcnet"\n' '[postinst]\nstages = ["tty"]\n'
            )
            context = Context.create(root, "boot", str(child))
            config = load_config(context)
            self.assertEqual(config.value("qemu", "profile"), "linux-1.2")
            self.assertEqual(config.value("qemu", "network", "device"), "pcnet")
            self.assertEqual(config.value("postinst", "stages"), ["tty"])

    def test_toml_qemu_and_extraction_models(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "distro/version"
            directory.mkdir(parents=True)
            (directory / "config.toml").write_text(
                '[qemu]\nprofile = "linux-2.0"\nram = "32M"\n'
                '[qemu.network]\ndevice = "pcnet"\n'
                '[extract]\nsource = "disc1.iso"\nboot_image = "images/boot.img"\n'
            )
            context = Context.create(root, "boot", str(directory))
            qemu = load_qemu_config(load_config(context))
            extraction = toml_extraction(load_config(context))
            self.assertEqual(qemu.ram, "32M")
            self.assertEqual(qemu.nic, "pcnet")
            self.assertEqual(extraction.source, "disc1.iso")
            self.assertEqual(extraction.boot_image, "images/boot.img")

    def test_qemu_rejects_unknown_toml_settings(self) -> None:
        config = RetroConfig(
            SimpleNamespace(name="test"),
            {"qemu": {"profile": "default", "unsupported_flag": True}},
        )
        with self.assertRaisesRegex(ConfigError, "unsupported_flag"):
            load_qemu_config(config)

    def test_installer_options_are_collected_from_logical_tables(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "debian/1.1"
            directory.mkdir(parents=True)
            (directory / "config.toml").write_text(
                '[install.network]\nhostname = "buzz"\n'
                "[install.debian]\ndriver_floppy = false\nrelogin = true\n"
            )
            context = Context.create(root, "install", str(directory))
            options = load_config(context).options(DinstallOptions)
            self.assertEqual(options.hostname, "buzz")
            self.assertIsNone(options.driver_floppy)
            self.assertTrue(options.relogin)

    def test_postinstall_config_renders_logical_sections(self) -> None:
        rendered = MediaStager._render_postinst_config(
            {
                "stages": ["network", "tty"],
                "network": {"hostname": "retro"},
                "tty": {"baud": 19200},
                "reboot": True,
            }
        )
        self.assertIn("POSTINST_STAGES='network tty'", rendered)
        self.assertIn("NET_HOSTNAME='retro'", rendered)
        self.assertIn("TTY_BAUD='19200'", rendered)
        self.assertIn("POSTINST_REBOOT='true'", rendered)


class QemuTests(unittest.TestCase):
    def runtime(self, root: Path, config: QemuConfig | None = None) -> QemuRuntime:
        directory = root / "distro"
        (directory / "qemu.d").mkdir(parents=True)
        (directory / "qemu.d/boot.img").touch()
        qemu = config or QemuConfig()
        qemu.apply_profile()
        return QemuRuntime(Context(root, directory, "boot", root / "temporary"), qemu)

    def test_default_forwards_use_the_documented_port_ranges(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runtime = self.runtime(Path(temporary))
            with patch("hostlib.qemu.available_port", side_effect=[2200, 2300]) as port:
                command = runtime.command()
                runtime.command()

            netdev = command[command.index("-netdev") + 1]
            self.assertIn("hostfwd=tcp:127.0.0.1:2200-:22", netdev)
            self.assertIn("hostfwd=tcp:127.0.0.1:2300-:23", netdev)
            self.assertEqual([call.args[0] for call in port.call_args_list], [2200, 2300])

    def test_explicit_empty_forward_list_disables_port_forwards(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            config = QemuConfig(forwards=[])
            runtime = self.runtime(Path(temporary), config)
            netdev = runtime.command()[runtime.command().index("-netdev") + 1]
            self.assertEqual(netdev, "user,id=internet")

    def test_device_report_includes_endpoints_disks_and_character_sockets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runtime = self.runtime(Path(temporary), QemuConfig(forwards=[[2200, 22]]))
            with self.assertLogs("hostlib.qemu", "INFO") as report:
                runtime._report_devices()

            text = "\n".join(report.output)
            self.assertIn("QEMU endpoints:", text)
            self.assertIn("QMP:     qmp.sock", text)
            self.assertNotIn(str(runtime.directory), text)
            self.assertIn("SSH:    localhost:2200 -> guest :22", text)
            self.assertIn("Guest disks:", text)
            self.assertIn("file=boot.img", text)
            self.assertIn("Guest character devices:", text)
            self.assertIn("unix:ttyS3.sock", text)

    def test_ensure_disk_requires_boot_media_and_reports_qemu_img_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            runtime = self.runtime(root)
            (runtime.directory / "boot.img").unlink()
            with self.assertRaisesRegex(CommandError, "No bootable devices"):
                runtime.ensure_disk()
            (runtime.directory / "boot.img").touch()
            with patch("hostlib.qemu.subprocess.run", return_value=SimpleNamespace(returncode=1)):
                with self.assertRaisesRegex(CommandError, "Could not create"):
                    runtime.ensure_disk()

    def test_drives_include_floppy_cdrom_fat_and_disk_options(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = QemuConfig(hda_options="cache=writeback")
            runtime = self.runtime(root, config)
            (runtime.directory / "hda.img").touch()
            (runtime.directory / "install.iso").touch()
            (runtime.directory / "fat").mkdir()
            drives = runtime._drives()
            rendered = "\n".join(drives)
            self.assertIn("file=boot.img", rendered)
            self.assertIn("file=hda.img,cache=writeback", rendered)
            self.assertIn("media=cdrom,file=install.iso", rendered)
            self.assertIn("file=fat:rw:fat", rendered)


class QemuLifecycleTests(unittest.IsolatedAsyncioTestCase):
    async def test_start_removes_stale_sockets_and_uses_qemu_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "distro/qemu.d"
            directory.mkdir(parents=True)
            (directory / "boot.img").touch()
            stale = directory / "qmp.sock"
            stale.touch()
            context = Context(root, directory.parent, "boot", root / "temp")
            config = QemuConfig(network_enabled=False)
            config.apply_profile()
            runtime = QemuRuntime(context, config)
            process = SimpleNamespace()
            with (
                patch.object(QemuRuntime, "ensure_disk"),
                patch.object(QemuRuntime, "_report_devices"),
                patch(
                    "hostlib.qemu.asyncio.create_subprocess_exec", AsyncMock(return_value=process)
                ) as create,
            ):
                self.assertIs(await runtime.start(), process)
            self.assertFalse(stale.exists())
            self.assertEqual(create.await_args.kwargs["cwd"], directory)
            self.assertEqual(create.await_args.args[0], config.system)


class MediaStagerTests(unittest.TestCase):
    def test_directory_extraction_decompresses_links_and_stages_guestlib(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            (root / "guestlib/postinst.sh").write_text("#!/bin/sh\n")
            context, config = temporary_config(
                root,
                "distro/version",
                {
                    "extract": {
                        "source": "media",
                        "boot_image": "boot.gz",
                        "fat_files": ["README"],
                        "packages": "packages",
                        "decompress": ["boot.gz"],
                        "truncate": ["boot"],
                        "boot_link": "boot",
                        "packages_as_install": True,
                    },
                    "postinst": {"stages": ["network"], "network": {"hostname": "retro"}},
                },
            )
            source = config.download_dir / "media"
            (source / "packages/a1").mkdir(parents=True)
            with gzip.open(source / "boot.gz", "wb") as output:
                output.write(b"x" * (1600 * 1024))
            (source / "README").write_text("media")
            (source / "packages/a1/base.tgz").touch()
            MediaStager(context, config).extract()
            self.assertEqual((context.qemu_dir / "boot").stat().st_size, 1440 * 1024)
            self.assertTrue((context.qemu_dir / "boot.img").is_symlink())
            self.assertTrue((context.qemu_dir / "fat/install/a1/base.tgz").is_file())
            generated = context.qemu_dir / "fat/guestlib.d/distro/config.sh"
            self.assertIn("NET_HOSTNAME='retro'", generated.read_text())
            self.assertTrue((context.qemu_dir / ".extracted").exists())

    def test_existing_marker_refreshes_guestlib_without_reextracting(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            (root / "guestlib/current").write_text("new")
            context, config = temporary_config(root, "distro/version", {"extract": {}})
            context.qemu_dir.mkdir()
            (context.qemu_dir / ".extracted").touch()
            old = context.qemu_dir / "fat/guestlib.d"
            old.mkdir(parents=True)
            (old / "stale").touch()
            MediaStager(context, config).extract()
            self.assertFalse((old / "stale").exists())
            self.assertEqual((old / "current").read_text(), "new")

    def test_custom_extraction_script_receives_project_environment(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            context, config = temporary_config(
                root, "distro/version", {"extract": {"custom_script": "extract.sh"}}
            )
            (context.config / "extract.sh").write_text("true\n")
            with patch(
                "hostlib.media.subprocess.run", return_value=SimpleNamespace(returncode=0)
            ) as run:
                MediaStager(context, config).extract()
            environment = run.call_args.kwargs["env"]
            self.assertEqual(environment["DISTRO_D"], str(context.config))
            self.assertEqual(environment["QEMU_D"], str(context.qemu_dir))
            self.assertEqual(run.call_args.args[0][-1], str(context.config / "extract.sh"))

    def test_extraction_and_postinstall_schema_errors_are_rejected(self) -> None:
        context = SimpleNamespace(name="test")
        for table, message in (
            ({"extra_images": "boot.img"}, "array of strings"),
            ({"packages_as_install": "yes"}, "must be a boolean"),
            ({"unknown": True}, "Unknown extract"),
        ):
            with self.assertRaisesRegex(ConfigError, message):
                toml_extraction(RetroConfig(context, {"extract": table}))
        for table, message in (
            ({"stages": ["mystery"]}, "Unknown post-install"),
            ({"stages": ["custom"]}, "requires postinst.custom_script"),
            ({"stages": [], "network": []}, "must be a table"),
        ):
            with self.assertRaisesRegex(ConfigError, message):
                MediaStager._validate_postinst(table)


class FdiskTests(unittest.TestCase):
    def test_range_parses_common_classic_fdisk_prompts(self) -> None:
        serial = unittest.mock.Mock()
        serial.wait.return_value = "First cylinder ([1]-[520], default 1): "
        driver = Fdisk(SimpleNamespace(serial=serial))
        self.assertEqual(driver._range("First cylinder"), (1, 520))

    def test_partition_creates_swap_and_root_and_writes_table(self) -> None:
        sent: list[str] = []

        class Serial:
            def wait(self, expected, regex=False):
                if regex:
                    label = "First" if "First" in expected else "Last"
                    return f"{label} cylinder (1-520): "
                return expected

            def wait_any(self, *_):
                return 1, "No partition is defined yet"

            def send(self, value):
                sent.append(value)

        session = SimpleNamespace(
            serial=Serial(),
            serial_console_echo=unittest.mock.Mock(),
            serial_shell_send=unittest.mock.Mock(),
        )
        Fdisk(session).partition(swap_mb=32)
        session.serial_shell_send.assert_called_once_with(
            "[ -b /dev/hda ] || mknod /dev/hda b 3 0; fdisk /dev/hda", wait=False
        )
        self.assertIn("+32M", sent)
        self.assertEqual(sent[-1], "w")


class InstallPlanTests(unittest.TestCase):
    def test_prompt_sequence_interpolates_config_and_types_embedded_enter(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "distro/version"
            directory.mkdir(parents=True)
            (directory / "config.toml").write_text(
                '[install]\ndriver = "prompt-sequence"\n'
                '[install.network]\nhostname = "retro"\n'
                '[[install.steps]]\naction = "type"\n'
                'text = "${install.network.hostname}\\n"\n'
                '[[install.steps]]\naction = "press"\nkeys = ["f12"]\n'
            )
            session = SimpleNamespace(
                config=load_config(Context.create(root, "install", str(directory))),
                kb_type=unittest.mock.Mock(),
                kb_press=unittest.mock.Mock(),
            )
            run_configured_install(session)
            session.kb_type.assert_called_once_with("retro\n")
            session.kb_press.assert_called_once_with("f12")

    def test_prompt_sequence_rejects_invalid_boolean(self) -> None:
        config = RetroConfig(
            SimpleNamespace(),
            {
                "install": {
                    "driver": "prompt-sequence",
                    "steps": [
                        {
                            "action": "serial-shell-send",
                            "command": "setup",
                            "wait": "false",
                        }
                    ],
                }
            },
        )
        with self.assertRaisesRegex(ConfigError, "wait must be a boolean"):
            validate_install_config(config)

    def test_prompt_sequence_executes_every_supported_action(self) -> None:
        steps = [
            {"action": "wait", "transport": "vga", "text": "Ready", "match": "line"},
            {"action": "wait", "transport": "serial", "text": "login:", "match": "regex"},
            {"action": "type", "text": "${install.network.hostname}\n"},
            {"action": "press", "keys": ["tab", "ret"], "repeat": 2},
            {"action": "prompt", "questions": ["one", "two"], "answer": "yes", "regex": True},
            {"action": "serial-shell-start", "screen_prompt": "$", "serial_prompt": "#"},
            {"action": "serial-shell-send", "command": "setup", "wait": False, "prompt": "$"},
            {"action": "serial-send", "text": "raw"},
            {"action": "serial-shell-exit", "screen_prompt": "done"},
            {"action": "console-echo", "text": "Installing"},
            {"action": "partition", "device": "/dev/sda", "swap_mb": 32},
            {"action": "change-floppy", "image": "root.img"},
            {"action": "set-boot", "device": "c"},
            {"action": "run-postinst", "password": "secret", "login": "login:", "shell": "#"},
        ]
        config = RetroConfig(
            SimpleNamespace(),
            {
                "install": {
                    "driver": "prompt-sequence",
                    "network": {"hostname": "retro"},
                    "steps": steps,
                }
            },
        )
        serial = unittest.mock.Mock()
        session = SimpleNamespace(
            config=config,
            serial=serial,
            vga_wait=unittest.mock.Mock(),
            kb_type=unittest.mock.Mock(),
            kb_press=unittest.mock.Mock(),
            serial_shell_start=unittest.mock.Mock(),
            serial_shell_send=unittest.mock.Mock(),
            serial_shell_exit=unittest.mock.Mock(),
            serial_console_echo=unittest.mock.Mock(),
            change_floppy=unittest.mock.Mock(),
            set_boot=unittest.mock.Mock(),
            run_postinst=unittest.mock.Mock(),
        )
        with patch.object(installers, "Fdisk") as fdisk:
            run_configured_install(session)
        session.vga_wait.assert_called_once_with("Ready", match=Match.LINE, timeout=None)
        serial.wait.assert_called_once_with("login:", line=False, regex=True, timeout=None)
        session.kb_type.assert_called_once_with("retro\n")
        self.assertEqual(session.kb_press.call_count, 2)
        serial.prompt.assert_called_once_with("one", "two", answer="yes", regex=True)
        fdisk.return_value.partition.assert_called_once_with("/dev/sda", 32)
        session.run_postinst.assert_called_once_with("secret", login="login:", shell="#")

    def test_installer_validation_rejects_bad_drivers_controls_and_steps(self) -> None:
        cases = (
            ({"install": {}}, "must set install.driver"),
            ({"install": {"driver": "unknown"}}, "Unknown install driver"),
            ({"install": {"driver": "prompt-sequence", "steps": []}}, "requires install.steps"),
            (
                {
                    "install": {
                        "driver": "prompt-sequence",
                        "steps": [{"action": "press", "keys": 3}],
                    }
                },
                "keys must be strings",
            ),
            (
                {"install": {"driver": "debian-dinstall", "boot": "boot:"}},
                "install.boot must be a table",
            ),
            (
                {"install": {"driver": "redhat-perl", "redhat": {}}},
                "install.redhat.flow must be a string",
            ),
        )
        for data, message in cases:
            with self.subTest(message=message):
                with self.assertRaisesRegex(ConfigError, message):
                    validate_install_config(RetroConfig(SimpleNamespace(), data))


class RedHatDriverTests(unittest.TestCase):
    def test_unattended_flow_boots_reboots_and_runs_postinstall(self) -> None:
        config = RetroConfig(
            SimpleNamespace(),
            {
                "install": {
                    "accounts": {"root_password": "secret"},
                    "prompts": {"login_prompt": "login:", "shell_prompt": "#"},
                    "boot": {"prompt": "boot:", "command": "linux ks=floppy"},
                    "completion": {"prompt": "Complete", "reboot": True, "postinst": True},
                }
            },
        )
        session = SimpleNamespace(
            config=config,
            vga_wait=unittest.mock.Mock(),
            kb_type=unittest.mock.Mock(),
            set_boot=unittest.mock.Mock(),
            run_postinst=unittest.mock.Mock(),
        )
        redhat.run_unattended(session, config.section("install"))
        self.assertEqual(session.vga_wait.call_args_list[0].args, ("boot:",))
        session.kb_type.assert_any_call("linux ks=floppy\n")
        session.set_boot.assert_called_once_with("c")
        session.run_postinst.assert_called_once_with("secret", login="login:", shell="#")

    def test_c_installer_composes_4x_phases_and_rejects_unknown_flow(self) -> None:
        session = SimpleNamespace(options=lambda _: redhat.CInstallerOptions(flow="4x"))
        installer = unittest.mock.Mock()
        installer.o.flow = "4x"
        with patch.object(redhat, "CInstaller", return_value=installer):
            redhat.run_c_installer(session, {})
        for method in (
            installer.start,
            installer.partition_4x,
            installer.components_40,
            installer.finish_components,
            installer.x11_4x,
            installer.network,
            installer.finish,
        ):
            method.assert_called_once_with()
        installer.o.flow = "mystery"
        with patch.object(redhat, "CInstaller", return_value=installer):
            with self.assertRaisesRegex(ConfigError, "Unknown Red Hat C installer flow"):
                redhat.run_c_installer(session, {})

    def test_early_redhat_flow_composes_release_specific_phases(self) -> None:
        session = SimpleNamespace()
        installer = unittest.mock.Mock()
        with patch.object(redhat_early, "PerlInstaller", return_value=installer):
            redhat_early.run_perl_installer(session, {"redhat": {"flow": "1.1"}})
        installer.boot.assert_called_once_with()
        installer.load_ramdisk.assert_called_once_with("rootdisk.img")
        installer.insert_boot_disk.assert_called_once_with()
        with patch.object(redhat_early, "PerlInstaller", return_value=installer):
            with self.assertRaisesRegex(ConfigError, "Unknown Red Hat Perl installer flow"):
                redhat_early.run_perl_installer(session, {"redhat": {"flow": "unknown"}})


class KeyboardTests(unittest.TestCase):
    def test_encode(self) -> None:
        self.assertEqual(encode("Ab c?"), ["shift-a", "b", "spc", "c", "shift-slash"])

    def test_encode_embedded_control_keys(self) -> None:
        self.assertEqual(encode("root\n\t"), ["r", "o", "o", "t", "ret", "tab"])

    def test_rejects_unsupported_characters(self) -> None:
        with self.assertRaises(ValueError):
            encode("🐧")


class _DialogSerial:
    def __init__(self, text: str) -> None:
        self.text = text
        self.offset = 0
        self.answers: list[str] = []

    def mark(self) -> int:
        return self.offset

    def rewind(self, offset: int) -> None:
        self.offset = offset

    def read_until(self, pattern: re.Pattern[str]) -> str:
        match = pattern.search(self.text, self.offset)
        assert match
        start, self.offset = self.offset, match.end()
        return self.text[start : self.offset]

    def send(self, text: str) -> None:
        self.answers.append(text)


class DialogTests(unittest.TestCase):
    def test_callback_rewinds_the_screen_for_nested_handler(self) -> None:
        serial = _DialogSerial("TITLE: Main\nTYPE: menu\nITEM: Next :: Install\nRESPONSE:\n")
        dialog = Dialog(serial)

        def handler(_: str) -> None:
            dialog.answer(Choice("menu", "Main", "Next"))

        dialog.answer(Choice("menu", "Main", handler, item="Next :: Install"))
        self.assertEqual(serial.answers, ["Next"])

    def test_pkgtool_callback_consumes_rewound_trigger_screen(self) -> None:
        def screen(title: str, widget: str) -> str:
            return f"TITLE: {title}\nTYPE: {widget}\nRESPONSE:\n"

        serial = _DialogSerial(
            screen("CONFIGURE NETWORK?", "yesno")
            + screen("NETWORK SETUP COMPLETE", "msgbox")
            + screen("SETUP COMPLETE", "msgbox")
        )
        dialog = Dialog(serial)
        Pkgtool(SimpleNamespace(dialog=dialog), PkgtoolOptions())._configure()
        self.assertEqual(serial.answers, ["yes", "ok", "ok"])

    def test_none_answer_leaves_lookahead_for_outer_dispatch(self) -> None:
        def screen(item: str) -> str:
            return "TITLE: Main\nTYPE: menu\n" f"ITEM: Next :: {item}\nRESPONSE:\n"

        serial = _DialogSerial(screen("Install Base") + screen("Install Kernel"))
        dialog = Dialog(serial)

        def install_base(_: str) -> None:
            dialog.answer(Choice("menu", "Main", "Next", item="Install Base"))
            dialog.answer(Choice("menu", "Main", None, terminal=True))

        dialog.answer_until(
            Choice("menu", "Main", install_base, item="Install Base"),
            Choice("menu", "Main", "Next", item="Install Kernel", terminal=True),
        )
        self.assertEqual(serial.answers, ["Next", "Next"])


class DinstallTests(unittest.TestCase):
    def test_media_dialogs_use_the_configured_fat_mount(self) -> None:
        dialog = unittest.mock.Mock()
        session = SimpleNamespace(dialog=dialog)
        driver = Dinstall(
            session,
            DinstallOptions(fat_mount="/media/retro", kernel_floppy=None),
        )

        driver._base("")
        base_choices = dialog.answer_until.call_args.args
        self.assertEqual(base_choices[1].answer, "/media/retro")
        self.assertEqual(base_choices[3].answer, "/media/retro")

        driver._kernel("")
        kernel_choices = dialog.answer_until.call_args.args
        self.assertEqual(kernel_choices[3].answer, "/media/retro")
        self.assertEqual(kernel_choices[5].answer, "/media/retro")


class PkgtoolPromptTests(unittest.TestCase):
    def test_boot_prompt_can_be_disabled_when_kernel_is_already_running(self) -> None:
        session = SimpleNamespace(
            vga_wait=unittest.mock.Mock(),
            kb_type=unittest.mock.Mock(),
            change_floppy=unittest.mock.Mock(),
            kb_press=unittest.mock.Mock(),
            dialog=SimpleNamespace(),
        )
        with patch("hostlib.installers.slackware.Pkgtool.install"):
            boot_pkgtool(
                session,
                boot_prompt=None,
                root_prompt="insert root disk",
                options=PkgtoolOptions(),
            )

        session.vga_wait.assert_called_once_with("insert root disk", match=Match.LINE)
        session.kb_type.assert_not_called()

    def test_boot_answers_a_second_vfs_prompt_after_changing_root_disk(self) -> None:
        session = SimpleNamespace(
            vga_wait=unittest.mock.Mock(),
            kb_type=unittest.mock.Mock(),
            change_floppy=unittest.mock.Mock(),
            kb_press=unittest.mock.Mock(),
            dialog=SimpleNamespace(),
        )
        with patch("hostlib.installers.slackware.Pkgtool.install"):
            boot_pkgtool(
                session,
                root_prompt="insert root disk",
                continuation_prompt="VFS: Insert root floppy and press ENTER",
                options=PkgtoolOptions(),
            )

        session.change_floppy.assert_called_once_with("root.img")
        self.assertEqual(
            session.kb_press.call_args_list,
            [unittest.mock.call("ret"), unittest.mock.call("ret")],
        )
        session.vga_wait.assert_any_call("VFS: Insert root floppy and press ENTER")

    def test_python_driver_covers_every_fixed_shell_prompt(self) -> None:
        """Keep the Python dispatch table aligned with the original driver."""
        root = Path(__file__).resolve().parent.parent
        shell = (root / "slackware/pkgtool.sh").read_text()
        python = (root / "hostlib/installers/slackware.py").read_text()

        commands: list[str] = []
        pending = ""
        for line in shell.splitlines():
            stripped = line.strip()
            if pending or stripped.startswith("dialog_answer"):
                pending += stripped.removesuffix("\\").strip() + " "
                if not stripped.endswith("\\"):
                    commands.append(pending)
                    pending = ""

        shell_prompts: list[str] = []
        for command in commands:
            words = shlex.split(command, comments=True)
            position = 1
            if position < len(words) and words[position] == "-l":
                position += 2
            while position < len(words):
                if words[position] == "-x":
                    position += 1
                position += 1  # widget
                if position < len(words) and words[position] == "-r":
                    position += 1
                if position >= len(words):
                    break
                shell_prompts.append(words[position])
                position += 1
                if position < len(words) and words[position] == "-d":
                    position += 1
                    if position < len(words) and words[position] == "-r":
                        position += 1
                elif position < len(words) and words[position] == "-f":
                    position += 1
                position += 1  # answer, description, or callback

        tree = ast.parse(python)
        python_prompts = {
            call.args[1].value
            for call in ast.walk(tree)
            if isinstance(call, ast.Call)
            and isinstance(call.func, ast.Name)
            and call.func.id == "Choice"
            and len(call.args) > 1
            and isinstance(call.args[1], ast.Constant)
            and isinstance(call.args[1].value, str)
        }
        fixed_shell_prompts = {prompt for prompt in shell_prompts if not prompt.startswith("$")}

        self.assertEqual(len(shell_prompts), 97)
        self.assertEqual(len(set(shell_prompts)), 83)
        self.assertEqual(fixed_shell_prompts - python_prompts, set())


class SysinstallTests(unittest.TestCase):
    def test_bootdisk_prompt_creates_a_1440k_floppy(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            serial = SimpleNamespace(
                wait_any=unittest.mock.Mock(side_effect=[(1, ""), (2, "")]),
                send=unittest.mock.Mock(),
            )
            session = SimpleNamespace(
                qemu_dir=Path(temporary),
                serial=serial,
                change_floppy=unittest.mock.Mock(),
            )
            Sysinstall(session, SysinstallOptions())._packages()

            image = Path(temporary) / "bootdisk.img"
            self.assertEqual(image.stat().st_size, 1440 * 1024)
            session.change_floppy.assert_called_once_with("bootdisk.img")
            serial.send.assert_any_call("")


class ManifestCoverageTests(unittest.TestCase):
    def test_every_install_configuration_passes_driver_validation(self) -> None:
        root = Path(__file__).resolve().parent.parent
        validated = []
        for family in ("debian", "redhat", "slackware"):
            for path in (root / family).glob("**/config.toml"):
                context = Context(root, path.parent, "install", root / "temporary")
                config = load_config(context)
                if config.value("install", "driver"):
                    validate_install_config(config)
                    validated.append(path)
        self.assertEqual(len(validated), 61)

    def test_every_host_module_class_and_function_has_a_docstring(self) -> None:
        root = Path(__file__).resolve().parent.parent
        missing = []
        paths = [*(root / "hostlib").rglob("*.py"), root / "retro", root / "qmp"]
        for path in sorted(paths):
            tree = ast.parse(path.read_text(), filename=str(path))
            if ast.get_docstring(tree) is None:
                missing.append(f"{path.relative_to(root)}: module")
            for node in ast.walk(tree):
                if isinstance(node, (ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
                    if ast.get_docstring(node) is None:
                        missing.append(f"{path.relative_to(root)}:{node.lineno}: {node.name}")
        self.assertEqual(missing, [])

    def test_per_distro_qemu_and_download_python_manifests_are_removed(self) -> None:
        root = Path(__file__).resolve().parent.parent
        manifests = [
            path.relative_to(root)
            for family in ("slackware", "redhat", "debian", "cdrom")
            for name in ("qemu.py", "download.py")
            for path in (root / family).glob(f"**/{name}")
        ]
        self.assertEqual(manifests, [])

    def test_per_distro_extract_python_manifests_are_removed(self) -> None:
        root = Path(__file__).resolve().parent.parent
        manifests = [
            path.relative_to(root)
            for family in ("slackware", "redhat", "debian", "cdrom")
            for path in (root / family).glob("**/extract.py")
        ]
        self.assertEqual(manifests, [])

    def test_per_distro_install_python_manifests_are_removed(self) -> None:
        root = Path(__file__).resolve().parent.parent
        manifests = [
            path.relative_to(root)
            for family in ("slackware", "redhat", "debian")
            for path in (root / family).glob("**/install.py")
        ]
        self.assertEqual(manifests, [])

    def test_every_distribution_config_directory_has_toml(self) -> None:
        root = Path(__file__).resolve().parent.parent
        names = {
            "download.txt",
            "cdrom.txt",
            "slackmirror.txt",
            "debmirror.txt",
            "extract.sh",
            "qemu.sh",
            "install.sh",
            "postinst.sh",
        }
        directories = {
            path.parent
            for family in ("slackware", "redhat", "debian", "cdrom")
            for path in (root / family).glob("**/*")
            if path.is_file() and path.name in names and "qemu.d" not in path.parts
        }
        missing = [
            path.relative_to(root) for path in directories if not (path / "config.toml").is_file()
        ]
        self.assertEqual(missing, [])

    def test_only_exceptional_extractions_delegate_to_bash(self) -> None:
        root = Path(__file__).resolve().parent.parent
        custom = {
            path.parent.relative_to(root).as_posix()
            for path in root.glob("**/config.toml")
            if 'custom_script = "extract.sh"' in path.read_text()
        }
        self.assertEqual(
            custom,
            {
                "debian/1.1/infomagic",
                "debian/1.1/official",
                "debian/1.2/infomagic",
                "debian/1.2/official",
                "debian/1.3/infomagic",
                "debian/1.3/official",
                "slackware/1.01/channel1",
                "slackware/1.01/official+sls",
                "slackware/1.0beta/official",
                "slackware/1.0beta/official+sls",
                "slackware/1.1.1-infomagic",
                "slackware/3.6/linuxmall",
            },
        )

    def test_every_extract_shell_manifest_has_toml_extraction(self) -> None:
        root = Path(__file__).resolve().parent.parent
        for family in ("slackware", "redhat", "debian"):
            for script in (root / family).glob("**/extract.sh"):
                context = Context.create(root, "extract", str(script.parent))
                self.assertTrue(
                    load_config(context).section("extract"),
                    script.relative_to(root),
                )

    def test_shell_manifest_locations_have_toml_sections(self) -> None:
        root = Path(__file__).resolve().parent.parent
        cases = {
            "qemu": {"qemu.sh"},
            "download": {"download.txt", "cdrom.txt", "slackmirror.txt", "debmirror.txt"},
            "postinst": {"postinst.sh"},
        }
        for section, names in cases.items():
            directories = {
                path.parent
                for family in ("slackware", "redhat", "debian", "cdrom")
                for path in (root / family).glob("**/*")
                if path.is_file() and path.name in names and "qemu.d" not in path.parts
            }
            for directory in directories:
                context = Context.create(root, "boot", str(directory))
                self.assertTrue(
                    load_config(context).section(section),
                    directory.relative_to(root),
                )

    def test_custom_postinstall_stages_name_their_script(self) -> None:
        root = Path(__file__).resolve().parent.parent
        for path in root.glob("**/config.toml"):
            postinst = tomllib.loads(path.read_text()).get("postinst", {})
            if "custom" in postinst.get("stages", []):
                self.assertIsInstance(
                    postinst.get("custom_script"),
                    str,
                    path.relative_to(root),
                )

    def test_declarative_extraction_sources_are_isos_or_directories(self) -> None:
        root = Path(__file__).resolve().parent.parent
        archives = []
        for path in root.glob("**/config.toml"):
            extract = tomllib.loads(path.read_text()).get("extract", {})
            source = extract.get("source", "")
            if source and not source.lower().endswith(".iso"):
                archives.append(path.relative_to(root))
        self.assertEqual(archives, [])

    def test_every_install_shell_manifest_has_toml_driver(self) -> None:
        root = Path(__file__).resolve().parent.parent
        scripts = (
            script
            for family in ("slackware", "redhat", "debian")
            for script in (root / family).glob("**/install.sh")
        )
        for script in scripts:
            context = Context.create(root, "install", str(script.parent))
            driver = load_config(context).value("install", "driver")
            self.assertIn(driver, DRIVERS, script.relative_to(root))

    def test_prompt_sequence_configs_use_supported_actions(self) -> None:
        root = Path(__file__).resolve().parent.parent
        for path in root.glob("**/config.toml"):
            data = tomllib.loads(path.read_text())
            install = data.get("install", {})
            if install.get("driver") != "prompt-sequence":
                continue
            self.assertTrue(install.get("steps"), path.relative_to(root))
            for step in install["steps"]:
                self.assertIn(step.get("action"), STEP_ACTIONS, path.relative_to(root))

    def test_canonical_media_link_preserves_already_named_image(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            boot = Path(temporary) / "boot.img"
            boot.write_bytes(b"boot image")
            MediaStager._link("boot.img", boot)
            self.assertFalse(boot.is_symlink())
            self.assertEqual(boot.read_bytes(), b"boot image")


class VgaTests(unittest.IsolatedAsyncioTestCase):
    def test_decode_character_attribute_pairs(self) -> None:
        self.assertEqual(decode(b"A\x07B\x07\x00\x07C\x07", 2, 2), "AB\n C")

    def test_full_memory_decode_finds_scrolled_console_text(self) -> None:
        memory = b" " + b"\x07"
        memory *= 80 * 25
        memory += b"V\x07F\x07S\x07:\x07"
        self.assertNotIn("VFS:", decode(memory, 80, 25))
        self.assertIn("VFS:", decode(memory, 80, None))

    async def test_observer_polls_only_while_waiting(self) -> None:
        monitor = AsyncMock()
        with tempfile.TemporaryDirectory() as temporary:
            observer = ScreenObserver(monitor, Path(temporary), interval=0.001)
            observer._read = AsyncMock(side_effect=["boot:", "boot:", "login:"])
            await observer.start()
            self.assertEqual(observer._read.await_count, 0)
            screen = await observer.wait(lambda value: "login:" in value, 1)
            await observer.close()
        self.assertEqual(screen, "login:")
        self.assertEqual(observer._read.await_count, 3)
        self.assertEqual([item.text for item in observer.history], ["boot:", "login:"])

    async def test_wait_ignores_pre_return_screen_before_starting_timeout(self) -> None:
        monitor = AsyncMock()
        with tempfile.TemporaryDirectory() as temporary:
            observer = ScreenObserver(monitor, Path(temporary), interval=0.01)
            observer.history.append(Screen(0, "Full Name []:"))
            observer.invalidate()
            observer._read = AsyncMock(
                side_effect=["Full Name []:", "Is the information correct? [y/n]"]
            )
            screen = await observer.wait(
                lambda value: "information correct" in value,
                timeout=0.001,
            )
        self.assertIn("information correct", screen)


class MonitorTests(unittest.IsolatedAsyncioTestCase):
    async def test_disconnected_monitor_rejects_commands_and_events(self) -> None:
        from hostlib.qmp import QmpUnavailable

        monitor = Monitor(Path("missing.sock"))
        with self.assertRaisesRegex(QmpUnavailable, "not connected"):
            await monitor.execute("query-status")
        with self.assertRaisesRegex(QmpUnavailable, "not connected"):
            _ = monitor.events

    async def test_close_tolerates_a_peer_that_already_disconnected(self) -> None:
        client = SimpleNamespace(disconnect=AsyncMock(side_effect=EOFError))
        monitor = Monitor(Path("qmp.sock"))
        monitor._client = client
        await monitor.close()
        self.assertIsNone(monitor._client)

    async def test_send_key_uses_structured_qmp_key_events(self) -> None:
        monitor = Monitor(Path("unused.sock"))
        monitor.execute = AsyncMock()
        with patch("hostlib.qmp.asyncio.sleep", AsyncMock()) as sleep:
            await monitor.send_key("ctrl-alt-delete")
        monitor.execute.assert_awaited_once_with(
            "send-key",
            {
                "keys": [
                    {"type": "qcode", "data": "ctrl"},
                    {"type": "qcode", "data": "alt"},
                    {"type": "qcode", "data": "delete"},
                ],
                "hold-time": 10,
            },
        )
        sleep.assert_awaited_once_with(0.02)

    async def test_connect_retries_until_qmp_socket_is_ready(self) -> None:
        class ConnectError(Exception):
            pass

        class Client:
            attempts = 0

            def __init__(self, _: str) -> None:
                pass

            async def connect(self, _: str) -> None:
                Client.attempts += 1
                if Client.attempts < 3:
                    raise ConnectError("socket not ready")

            async def disconnect(self) -> None:
                pass

        qemu = ModuleType("qemu")
        qmp = ModuleType("qemu.qmp")
        qmp.ConnectError = ConnectError
        qmp.QMPClient = Client
        qemu.qmp = qmp
        with tempfile.TemporaryDirectory() as temporary:
            socket = Path(temporary) / "qmp.sock"
            socket.touch()
            with patch.dict(sys.modules, {"qemu": qemu, "qemu.qmp": qmp}):
                monitor = Monitor(socket, timeout=1)
                await monitor.connect()
                await monitor.close()
        self.assertEqual(Client.attempts, 3)


class SerialTests(unittest.IsolatedAsyncioTestCase):
    async def test_wait_consumes_prompt_padding_before_next_anchored_regex(
        self,
    ) -> None:
        console = SerialConsole(Path("unused.sock"))
        console._buffer = "Install type: "
        await console.wait("Install type:", timeout=0.1)
        self.assertEqual(console._offset, len(console._buffer))

        console._buffer += "Do you want prompting? "
        matched, _ = await console.wait_any(
            (r"^Do you want prompting[?]",), regex=True, timeout=0.1
        )
        self.assertEqual(matched, 0)

    async def test_line_wait_treats_current_offset_as_a_line_boundary(self) -> None:
        console = SerialConsole(Path("unused.sock"))
        console._buffer = "# # "
        console._offset = 2
        self.assertEqual(await console.wait("#", line=True, timeout=0.1), "# ")
        self.assertEqual(console._offset, 4)

    async def test_serial_output_is_transcribed_and_persisted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            socket = directory / "ttyS3.sock"
            console = SerialConsole(socket)
            console._reader = asyncio.StreamReader()
            console._reader.feed_data(b"guest output\r\n# ")
            console._reader.feed_eof()
            console._log_file = console.log_path.open("wb")
            with self.assertLogs("hostlib.serial", "INFO") as transcript:
                await console._drain()
                await console.wait("# ")
                await console.close()
            self.assertEqual((directory / "ttyS3.log").read_bytes(), b"guest output\r\n# ")
            self.assertTrue(any("➡️  guest output" in line for line in transcript.output))
            self.assertTrue(any("✅ # " in line for line in transcript.output))


class SessionTests(unittest.TestCase):
    def session(self, install=None):
        runtime = SimpleNamespace(
            monitor=AsyncMock(),
            vga=SimpleNamespace(wait=AsyncMock(), invalidate=unittest.mock.Mock()),
        )
        session = InstallSession(
            runtime,
            None,
            RetroConfig(SimpleNamespace(), {"install": install or {}}),
        )
        session._call = lambda coroutine: asyncio.run(coroutine)
        return session

    def test_line_wait_uses_trimmed_complete_lines(self) -> None:
        session = self.session()
        session.vga_wait("boot:", match=Match.LINE)
        predicate = session._runtime.vga.wait.call_args.args[0]
        self.assertTrue(predicate("heading\n  boot:  \n"))
        self.assertFalse(predicate("not boot: yet"))

    def test_type_uses_one_paced_qmp_request_per_key(self) -> None:
        session = self.session()
        with self.assertLogs("hostlib.session", "INFO") as transcript:
            session.kb_type("Ab\n")
        self.assertEqual(
            [call.args[0] for call in session._runtime.monitor.send_key.await_args_list],
            ["shift-a", "b", "ret"],
        )
        self.assertTrue(any("⌨️  Ab ↩️" in line for line in transcript.output))
        session._runtime.vga.invalidate.assert_called_once_with()

    def test_postinstall_command_uses_configured_fat_paths(self) -> None:
        session = self.session(
            {"disk": {"fat_partition": "/dev/sdb1", "fat_mount": "/media/retro"}}
        )
        self.assertIn("/dev/sdb1 /media/retro", session.postinst_command)
        self.assertIn("/media/retro/guestlib.d/postinst.sh", session.postinst_command)


if __name__ == "__main__":
    unittest.main()
