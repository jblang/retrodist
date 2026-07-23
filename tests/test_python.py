from __future__ import annotations

import asyncio
import ast
import gzip
import io
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib
from types import SimpleNamespace
from types import ModuleType
import unittest
from unittest.mock import AsyncMock
from unittest.mock import call
from unittest.mock import patch
import re
import sys
import tarfile
import zipfile

import py7zr

from hostlib.config import QemuConfig, RetroConfig, load_config, load_qemu_config
from hostlib.context import Context
from hostlib.errors import CommandError, ConfigError, RetroError
from hostlib import cli, download, operations, qmp_cli, tagfiles
from hostlib.fdisk import Fdisk
from hostlib.keyboard import encode
from hostlib.dialog import Choice, Dialog
from hostlib.debian_packages import (
    DebianPackage,
    load_packages,
    render_installer,
    resolve_packages,
)
from hostlib.session import InstallSession, Match
from hostlib.serial import SerialConsole
from hostlib.installers.slackware import Pkgtool, PkgtoolOptions, boot_pkgtool
from hostlib.installers.debian import Dinstall, DinstallOptions
from hostlib.installers.slackware_sysinstall import Sysinstall, SysinstallOptions
from hostlib.installers import (
    DRIVERS,
    STEP_ACTIONS,
    run_configured_install,
    validate_install_config,
)
from hostlib import installers
from hostlib.installers import redhat_c, redhat_perl
from hostlib.vga import Screen, ScreenObserver, decode
from hostlib.media import Extraction, MediaStager, toml_extraction
from hostlib.schemas import DebianPackagesConfig, PostinstConfig
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
    return context, RetroConfig(context=context, data=data or {})


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
    def test_python_owns_canonical_names_and_bash_commands_are_removed(self) -> None:
        root = Path(__file__).resolve().parent.parent
        project = tomllib.loads((root / "pyproject.toml").read_text())
        self.assertEqual(
            project["project"]["scripts"],
            {"retro": "hostlib.cli:main", "qmp": "hostlib.qmp_cli:main"},
        )
        self.assertIn("from hostlib.cli import main", (root / "retro").read_text())
        self.assertIn("from hostlib.qmp_cli import main", (root / "qmp").read_text())
        self.assertFalse((root / "retro-bash").exists())
        self.assertFalse((root / "qmp-bash").exists())
        self.assertFalse((root / "hostlib-bash").exists())

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
            target = config.download_dir / "nested/disk.img"

            def run(command, *, check):
                self.assertFalse(check)
                Path(command[command.index("--output-document") + 1]).write_bytes(b"media")
                return SimpleNamespace(returncode=0)

            with patch("hostlib.download.subprocess.run", side_effect=run) as wget:
                Download = download.Downloader(context, config)
                Download.run()
                Download.run()
            self.assertEqual((config.download_dir / "nested/disk.img").read_bytes(), b"media")
            wget.assert_called_once_with(
                [
                    "wget",
                    "--no-verbose",
                    "--show-progress",
                    "--output-document",
                    str(target),
                    "https://x",
                ],
                check=False,
            )

    def test_download_rejects_unsafe_paths_and_invalid_entries(self) -> None:
        context = SimpleNamespace()
        for files, message in (
            ([{"path": "../disk.img", "url": "https://x"}], "Unsafe"),
            ([{"path": "disk.img"}], "Missing URL"),
            ("disk.img", "array of tables"),
        ):
            config = RetroConfig(context=context, data={"download": {"files": files}})
            with self.assertRaisesRegex(ConfigError, message):
                if isinstance(files, list) and files and "url" in files[0]:
                    settings = config.download
                    download.Downloader(context, config)._download(settings, Path("unused"))
                else:
                    config.download

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

            def run(command, *, check):
                Path(command[command.index("--output-document") + 1]).write_bytes(b"iso")
                return SimpleNamespace(returncode=0)

            with patch("hostlib.download.subprocess.run", side_effect=run):
                download.Downloader(context, config).run()
            linked = context.qemu_dir / "disc.iso"
            self.assertTrue(linked.is_symlink())
            self.assertEqual(linked.read_bytes(), b"iso")

    def test_failed_download_removes_partial_file(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "disk.img"
            target.write_bytes(b"partial")
            with (
                patch(
                    "hostlib.download.subprocess.run",
                    return_value=SimpleNamespace(returncode=8),
                ),
                self.assertRaisesRegex(CommandError, "wget failed with status 8"),
            ):
                download.Wget().retrieve("https://x/disk.img", target)
            self.assertFalse(target.exists())

    def test_missing_wget_is_reported(self) -> None:
        with (
            patch("hostlib.download.subprocess.run", side_effect=FileNotFoundError),
            self.assertRaisesRegex(CommandError, "wget is required"),
        ):
            download.Wget().retrieve("https://x/disk.img", Path("disk.img"))

    def test_mirror_release_names_cannot_escape_the_download_directory(self) -> None:
        downloader = download.Downloader(SimpleNamespace(), SimpleNamespace())
        for method in (downloader._debian, downloader._slackware):
            with self.subTest(method=method.__name__):
                with self.assertRaisesRegex(ConfigError, "unsafe release name"):
                    method("../escape", Path("download.d"))

    def test_debian_mirror_downloads_configured_long_filename_package_trees(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            context, config = temporary_config(
                root,
                "debian/version",
                {
                    "download": {"debian_mirror": "buzz"},
                    "extract": {
                        "package_sources": [
                            "buzz/main/binary-i386",
                            "buzz/main/binary-all",
                        ]
                    },
                },
            )
            downloader = download.Downloader(context, config)
            with (
                patch.object(downloader, "_retrieve"),
                patch.object(downloader, "_mirror_tree") as mirror,
            ):
                downloader._debian("buzz", config.download_dir)
            urls = [call.args[0] for call in mirror.call_args_list]
            self.assertIn(
                "https://archive.debian.org/debian/dists/buzz/main/binary-i386/",
                urls,
            )
            self.assertIn(
                "https://archive.debian.org/debian/dists/buzz/main/binary-all/",
                urls,
            )
            self.assertNotIn(
                "https://archive.debian.org/debian/dists/buzz/main/msdos-i386/",
                urls,
            )

    def test_recursive_mirror_wraps_wget_with_layout_and_filter_options(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "release"
            with patch(
                "hostlib.download.subprocess.run",
                return_value=SimpleNamespace(returncode=0),
            ) as wget:
                download.Wget().mirror(
                    "https://x/releases/tree/", destination, ("*.md5", "*index*")
                )
            self.assertTrue(destination.is_dir())
            self.assertTrue((destination / download.Wget.MIRROR_SENTINEL).is_file())
            wget.assert_called_once_with(
                [
                    "wget",
                    "--no-verbose",
                    "--show-progress",
                    "--recursive",
                    "--no-parent",
                    "--no-host-directories",
                    "--cut-dirs=2",
                    f"--directory-prefix={destination}",
                    "--continue",
                    "--reject=*.md5,*index*",
                    "https://x/releases/tree/",
                ],
                check=False,
            )

    def test_completed_recursive_mirror_is_not_downloaded_again(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "release"
            destination.mkdir()
            (destination / download.Wget.MIRROR_SENTINEL).touch()
            with (
                patch("hostlib.download.subprocess.run") as wget,
                self.assertLogs(download.log, "INFO") as logs,
            ):
                download.Wget().mirror(
                    "https://x/releases/tree/", destination, ("*index*",)
                )
            wget.assert_not_called()
            self.assertEqual(
                logs.output,
                [
                    "INFO:hostlib.download:Skipping completed download; remove "
                    f"{os.path.relpath(destination / download.Wget.MIRROR_SENTINEL)} to retry",
                ],
            )

    def test_failed_recursive_mirror_is_not_marked_complete(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "release"
            with (
                patch(
                    "hostlib.download.subprocess.run",
                    return_value=SimpleNamespace(returncode=8),
                ),
                self.assertRaisesRegex(CommandError, "wget failed with status 8"),
            ):
                download.Wget().mirror("https://x/releases/tree/", destination, ("*index*",))
            self.assertFalse((destination / download.Wget.MIRROR_SENTINEL).exists())


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
        self.assertEqual(tagfiles._package_name("bash-1.14.7-i386-1.tgz"), "bash")
        self.assertEqual(tagfiles._package_name("kernel.tgz"), "kernel")

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
            tagfiles.prepare_tagfiles(context, qemu, context.config / "download.d")
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
            tagfiles.generate_default_tag(context, context.qemu_dir)
            generated = (context.config / "default.tag").read_text()
            self.assertIn("a    *            SKP", generated)
            self.assertIn("bash", generated)
            self.assertIn("# Bourne Again Shell", generated)


class ConfigTests(unittest.TestCase):
    def test_profile_only_fills_unspecified_values(self) -> None:
        config = QemuConfig(profile="linux-2.0", ram="32M")
        self.assertEqual(config.ram, "32M")
        self.assertEqual(config.disk.size, "8G")
        self.assertEqual(config.display.vga, "cirrus")

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
                'package_source = "slakware"\n'
            )
            context = Context.create(root, "boot", str(directory))
            qemu = load_qemu_config(load_config(context))
            extraction = toml_extraction(load_config(context))
            self.assertEqual(qemu.ram, "32M")
            self.assertEqual(qemu.network.device, "pcnet")
            self.assertEqual(extraction.source, "disc1.iso")
            self.assertEqual(extraction.boot_image, "images/boot.img")
            self.assertEqual(extraction.package_source, "slakware")
            self.assertEqual(extraction.package_dest, "packages")

    def test_qemu_rejects_unknown_toml_settings(self) -> None:
        config = RetroConfig(
            context=SimpleNamespace(name="test"),
            data={"qemu": {"profile": "default", "unsupported_flag": True}},
        )
        with self.assertRaisesRegex(ConfigError, "unsupported_flag"):
            load_qemu_config(config)

    def test_installer_options_are_collected_from_logical_tables(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            directory = root / "debian/1.1"
            directory.mkdir(parents=True)
            (directory / "config.toml").write_text(
                '[install]\ndriver = "debian-dinstall"\n'
                '[install.network]\nhostname = "buzz"\n'
                'domainname = "example.test"\nipaddr = "192.0.2.15"\n'
                "[install.debian]\ndriver_floppy = false\nrelogin = true\n"
            )
            context = Context.create(root, "install", str(directory))
            config = load_config(context)
            options = config.options(DinstallOptions)
            validate_install_config(config)
            self.assertEqual(options.network.hostname, "buzz")
            self.assertEqual(options.network.domain, "example.test")
            self.assertEqual(options.network.ip, "192.0.2.15")
            self.assertIsNone(options.driver_floppy)
            self.assertTrue(options.relogin)

    def test_nested_installer_option_errors_use_the_config_error_boundary(self) -> None:
        config = RetroConfig(
            context=SimpleNamespace(),
            data={"install": {"network": {"ip": 123}}},
        )
        with self.assertRaisesRegex(ConfigError, "Install option network has the wrong type"):
            config.options(DinstallOptions)

    def test_nested_installer_options_reject_conflicting_aliases(self) -> None:
        config = RetroConfig(
            context=SimpleNamespace(),
            data={"install": {"network": {"domain": "example.test", "domainname": "legacy.test"}}},
        )
        with self.assertRaisesRegex(ConfigError, "multiple aliases: domain, domainname"):
            config.options(DinstallOptions)

    def test_postinstall_config_renders_logical_sections(self) -> None:
        settings = RetroConfig(
            context=SimpleNamespace(),
            data={
                "postinst": {
                    "stages": ["network", "tty", "x11"],
                    "network": {"hostname": "retro"},
                    "tty": {"baud": 19200},
                    "x11": {"mouse_device": "/dev/ttyS2"},
                    "reboot": True,
                }
            },
        ).postinst
        rendered = MediaStager._render_postinst_config(settings)
        self.assertIn("POSTINST_STAGES='network tty x11'", rendered)
        self.assertIn("NET_HOSTNAME='retro'", rendered)
        self.assertNotIn("NET_GATEWAY=", rendered)
        self.assertIn("TTY_BAUD='19200'", rendered)
        self.assertIn("X11_MOUSEDEV='/dev/ttyS2'", rendered)
        self.assertIn("POSTINST_REBOOT='true'", rendered)

    def test_postinstall_network_uses_canonical_names_and_legacy_aliases(self) -> None:
        settings = RetroConfig(
            context=SimpleNamespace(),
            data={
                "postinst": {
                    "stages": ["network"],
                    "network": {
                        "hostname": "retro",
                        "domainname": "example.test",
                        "ipaddr": "192.0.2.15",
                    },
                }
            },
        ).postinst
        self.assertEqual(settings.network.domain, "example.test")
        self.assertEqual(settings.network.ip, "192.0.2.15")
        rendered = MediaStager._render_postinst_config(settings)
        self.assertIn("NET_DOMAINNAME='example.test'", rendered)
        self.assertIn("NET_IPADDR='192.0.2.15'", rendered)

    def test_postinstall_network_rejects_unknown_settings(self) -> None:
        config = RetroConfig(
            context=SimpleNamespace(),
            data={"postinst": {"network": {"namesrever": "192.0.2.3"}}},
        )
        with self.assertRaisesRegex(ConfigError, "namesrever"):
            config.postinst


class QemuTests(unittest.TestCase):
    def runtime(self, root: Path, config: QemuConfig | None = None) -> QemuRuntime:
        directory = root / "distro"
        (directory / "qemu.d").mkdir(parents=True)
        (directory / "qemu.d/boot.img").touch()
        qemu = config or QemuConfig()
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
            config = QemuConfig(network={"forwards": []})
            runtime = self.runtime(Path(temporary), config)
            netdev = runtime.command()[runtime.command().index("-netdev") + 1]
            self.assertEqual(netdev, "user,id=internet")

    def test_auxiliary_serial_backend_occupies_guest_ttys2(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runtime = self.runtime(
                Path(temporary), QemuConfig(serial={"auxiliary": "msmouse"})
            )
            serials = [
                value
                for option, value in runtime._chardevs()
                if option == "-serial"
            ]
            self.assertEqual(serials[2], "msmouse")
            self.assertIn("ttyS3.sock", serials[3])

    def test_device_report_includes_endpoints_disks_and_character_sockets(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            runtime = self.runtime(Path(temporary), QemuConfig(network={"forwards": [[2200, 22]]}))
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
            config = QemuConfig(disk={"hda_options": "cache=writeback"})
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
            config = QemuConfig(network={"enabled": False})
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


class DebianPackageTests(unittest.TestCase):
    def test_packages_parser_accepts_lowercase_fields_continuations_and_gzip(self) -> None:
        """Debian's control format and compressed indexes retain every field."""
        contents = (
            "Package: demo\npriority: optional\nsection: utils\n"
            "description: first line\n second line\nfilename: pool/demo_1.deb\n\n"
        )
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "Packages.gz"
            with gzip.open(source, "wt") as output:
                output.write(contents)
            packages = load_packages(source)
            self.assertEqual(packages[0].fields["description"], "first line\nsecond line")
            self.assertEqual(packages[0].name, "demo")

    def test_dependency_resolution_supports_versions_alternatives_and_providers(self) -> None:
        """Dependencies precede selected users and virtual packages resolve to providers."""
        packages = [
            DebianPackage(
                {
                    "package": "lib",
                    "priority": "required",
                    "section": "base",
                    "filename": "base/lib.deb",
                }
            ),
            DebianPackage(
                {
                    "package": "mailer",
                    "priority": "optional",
                    "section": "mail",
                    "provides": "mail-transport-agent",
                    "filename": "mail/mailer.deb",
                }
            ),
            DebianPackage(
                {
                    "package": "app",
                    "priority": "optional",
                    "section": "utils",
                    "depends": "lib (>= 1), missing | mail-transport-agent",
                    "filename": "utils/app.deb",
                }
            ),
        ]
        selected = resolve_packages(packages, DebianPackagesConfig(add=["app"]))
        self.assertEqual([package.name for package in selected], ["lib", "mailer", "app"])

    def test_skip_prevents_dependency_installation(self) -> None:
        """Skipping a required dependency reports an unresolved selection."""
        packages = [
            DebianPackage(
                {
                    "package": "library",
                    "priority": "optional",
                    "section": "libs",
                    "filename": "libs/library.deb",
                }
            ),
            DebianPackage(
                {
                    "package": "application",
                    "priority": "optional",
                    "section": "utils",
                    "depends": "library",
                    "filename": "utils/application.deb",
                }
            ),
        ]
        with self.assertRaisesRegex(ConfigError, "Unresolved dependency"):
            resolve_packages(packages, DebianPackagesConfig(add=["application"], skip=["library"]))

    def test_global_and_per_section_priorities_are_combined(self) -> None:
        """Section priorities override global priorities in their own section."""
        packages = [
            DebianPackage(
                {
                    "package": "base",
                    "priority": "required",
                    "section": "base",
                    "filename": "base/base.deb",
                }
            ),
            DebianPackage(
                {
                    "package": "editor",
                    "priority": "optional",
                    "section": "editors",
                    "filename": "editors/editor.deb",
                }
            ),
            DebianPackage(
                {
                    "package": "editor-extra",
                    "priority": "extra",
                    "section": "editors",
                    "filename": "editors/editor-extra.deb",
                }
            ),
            DebianPackage(
                {
                    "package": "game",
                    "priority": "extra",
                    "section": "games",
                    "filename": "games/game.deb",
                }
            ),
        ]
        config = DebianPackagesConfig(
            priorities=["required", "optional"],
            sections={"EDITORS": ["extra"]},
            add=["game"],
        )
        self.assertEqual(
            {package.name for package in resolve_packages(packages, config)},
            {"base", "editor-extra", "game"},
        )

    def test_skip_has_precedence_over_explicit_additions(self) -> None:
        """A skipped package remains excluded even when it is explicitly added."""
        packages = [
            DebianPackage(
                {
                    "package": "base",
                    "priority": "required",
                    "section": "base",
                    "filename": "base/base.deb",
                }
            ),
            DebianPackage(
                {
                    "package": "editor",
                    "priority": "optional",
                    "section": "editors",
                    "filename": "editors/editor.deb",
                }
            ),
        ]
        config = DebianPackagesConfig(
            priorities=["required"],
            sections={"editors": ["optional"]},
            add=["editor"],
            skip=["base", "editor"],
        )
        self.assertEqual(
            [package.name for package in resolve_packages(packages, config)], []
        )

    def test_explicit_packages_precede_priority_selections(self) -> None:
        """Explicit prerequisites install before packages selected by priority."""
        packages = [
            DebianPackage(
                {
                    "package": "zlib",
                    "priority": "standard",
                    "section": "devel",
                    "filename": "devel/zlib.deb",
                }
            ),
            DebianPackage(
                {
                    "package": "perl",
                    "priority": "important",
                    "section": "devel",
                    "filename": "devel/perl.deb",
                }
            ),
        ]
        config = DebianPackagesConfig(priorities=["important"], add=["zlib"])
        self.assertEqual(
            [package.name for package in resolve_packages(packages, config)],
            ["zlib", "perl"],
        )

    def test_installer_mounts_iso_and_uses_long_filenames(self) -> None:
        """CD-backed scripts mount the device and derive paths from Filename basenames."""
        package = DebianPackage(
            {
                "package": "demo",
                "priority": "optional",
                "section": "utils",
                "filename": "Debian/binary-i386/utils/demo_1.2-3.deb",
                "msdos-filename": "Debian/msdos-i386/utils/demo.deb",
            }
        )
        config = DebianPackagesConfig.model_validate(
            {
                "roots": ["/cdrom/buzz-fixed/binary-i386", "/cdrom/buzz/binary-i386"],
                "mount": {"device": "/dev/hdc", "point": "/cdrom"},
            }
        )
        script = render_installer([package], config)
        self.assertIn("mount -t 'iso9660' '/dev/hdc' '/cdrom'", script)
        self.assertIn("dpkg --install", script)
        self.assertIn("'/cdrom/buzz-fixed/binary-i386' '/cdrom/buzz/binary-i386'", script)
        self.assertIn("retro_dpkg_install 'utils' 'demo_1.2-3.deb'", script)
        self.assertNotIn("demo.deb", script)
        syntax = subprocess.run(
            ["sh", "-n"], input=script, text=True, capture_output=True, check=False
        )
        self.assertEqual(syntax.returncode, 0, syntax.stderr)


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
                        "boot_image": "media/boot.gz",
                        "fat_files": ["media/README"],
                        "package_source": "media/packages",
                        "package_index": "media/Packages.gz",
                        "package_dest": "install",
                        "decompress": ["boot.gz"],
                        "truncate": ["boot"],
                        "boot_link": "boot",
                    },
                    "postinst": {
                        "stages": ["packages", "network"],
                        "packages": {"add": ["demo"]},
                        "network": {"hostname": "retro"},
                    },
                },
            )
            source = config.download_dir / "media"
            (source / "packages/a1").mkdir(parents=True)
            with gzip.open(source / "boot.gz", "wb") as output:
                output.write(b"x" * (1600 * 1024))
            (source / "README").write_text("media")
            with gzip.open(source / "Packages.gz", "wt") as output:
                output.write(
                    "Package: demo\npriority: optional\nsection: utils\n"
                    "filename: pool/utils/demo_1.deb\n\n"
                )
            (source / "packages/a1/base.tgz").touch()
            (source / "packages/.complete").touch()
            MediaStager(context, config).extract()
            self.assertEqual((context.qemu_dir / "boot").stat().st_size, 1440 * 1024)
            self.assertTrue((context.qemu_dir / "boot.img").is_symlink())
            self.assertTrue((context.qemu_dir / "fat/install/a1/base.tgz").is_file())
            self.assertFalse((context.qemu_dir / "fat/install/.complete").exists())
            generated = context.qemu_dir / "fat/guestlib.d/distro/config.sh"
            self.assertIn("NET_HOSTNAME='retro'", generated.read_text())
            installer = context.qemu_dir / "fat/guestlib.d/distro/packages.sh"
            self.assertIn(
                "retro_dpkg_install 'utils' 'demo_1.deb'", installer.read_text()
            )
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

    def test_tar_extraction_stages_declared_images_and_package_tree(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            context, config = temporary_config(
                root,
                "distro/version",
                {
                    "extract": {
                        "source": "media.tar.gz",
                        "boot_image": "release/a1.img",
                        "package_source": "release",
                    }
                },
            )
            archive_path = config.download_dir / "media.tar.gz"
            archive_path.parent.mkdir()
            with tarfile.open(archive_path, "w:gz") as archive:
                for name, contents in (
                    ("release/a1.img", b"boot"),
                    ("release/a1/base.tgz", b"package"),
                ):
                    member = tarfile.TarInfo(name)
                    member.size = len(contents)
                    archive.addfile(member, io.BytesIO(contents))

            MediaStager(context, config).extract()

            self.assertEqual((context.qemu_dir / "a1.img").read_bytes(), b"boot")
            self.assertTrue((context.qemu_dir / "boot.img").is_symlink())
            self.assertEqual(
                (context.qemu_dir / "fat/packages/a1/base.tgz").read_bytes(), b"package"
            )

    def test_7z_source_stages_only_declared_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            context, config = temporary_config(
                root,
                "distro/version",
                {
                    "extract": {
                        "source": "media.7z",
                        "files": ["payload.txt"],
                        "fat_files": ["driver.tgz"],
                        "package_source": "release",
                    }
                },
            )
            config.download_dir.mkdir()
            source = root / "payload.txt"
            source.write_text("payload")
            ignored = root / "ignored.txt"
            ignored.write_text("ignored")
            driver = root / "driver.tgz"
            driver.write_text("driver")
            package = root / "base.tgz"
            package.write_text("package")
            with py7zr.SevenZipFile(config.download_dir / "media.7z", "w") as archive:
                archive.write(source, "payload.txt")
                archive.write(ignored, "ignored.txt")
                archive.write(driver, "driver.tgz")
                archive.write(package, "release/a1/base.tgz")

            MediaStager(context, config).extract()

            self.assertEqual((context.qemu_dir / "payload.txt").read_text(), "payload")
            self.assertFalse((context.qemu_dir / "ignored.txt").exists())
            self.assertEqual((context.qemu_dir / "fat/driver.tgz").read_text(), "driver")
            self.assertEqual(
                (context.qemu_dir / "fat/packages/a1/base.tgz").read_text(), "package"
            )

    def test_source_media_is_staged_before_the_custom_hook(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            context, config = temporary_config(
                root,
                "distro/version",
                {
                    "extract": {
                        "source": "media",
                        "boot_image": "boot.bin",
                        "custom_script": "extract.sh",
                    }
                },
            )
            (config.download_dir / "media").mkdir(parents=True)
            (config.download_dir / "media/boot.bin").write_bytes(b"boot")
            (context.config / "extract.sh").write_text("test -f boot.bin\ntouch hook-ran\n")

            MediaStager(context, config).extract()

            self.assertTrue((context.qemu_dir / "hook-ran").is_file())
            self.assertEqual((context.qemu_dir / "boot.img").readlink(), Path("boot.bin"))

    def test_zip_source_is_extracted_before_the_custom_hook(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            context, config = temporary_config(
                root,
                "distro/version",
                {
                    "extract": {
                        "source": "media.zip",
                        "files": ["payload.txt"],
                        "custom_script": "extract.sh",
                    }
                },
            )
            config.download_dir.mkdir()
            with zipfile.ZipFile(config.download_dir / "media.zip", "w") as archive:
                archive.writestr("payload.txt", "payload")
                archive.writestr("ignored.txt", "ignored")
            (context.config / "extract.sh").write_text("test -f payload.txt\ntouch hook-ran\n")

            MediaStager(context, config).extract()

            self.assertEqual((context.qemu_dir / "payload.txt").read_text(), "payload")
            self.assertTrue((context.qemu_dir / "hook-ran").is_file())
            self.assertFalse((context.qemu_dir / "ignored.txt").exists())

    def test_custom_extraction_script_receives_project_environment(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            context, config = temporary_config(
                root,
                "distro/version",
                {"extract": {"custom_script": "extract.sh"}},
            )
            (context.config / "extract.sh").write_text("true\n")
            with patch(
                "hostlib.media.subprocess.run", return_value=SimpleNamespace(returncode=0)
            ) as run:
                MediaStager(context, config).extract()
            environment = run.call_args.kwargs["env"]
            self.assertEqual(environment["DISTRO_D"], str(context.config))
            self.assertEqual(environment["QEMU_D"], str(context.qemu_dir))
            self.assertEqual(run.call_args.args[0][:4], ["bash", "-e", "-o", "pipefail"])
            self.assertEqual(run.call_args.args[0][-1], str(context.config / "extract.sh"))

    def test_custom_extraction_script_stops_at_the_first_failure(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            context, config = temporary_config(
                root,
                "distro/version",
                {"extract": {"custom_script": "extract.sh"}},
            )
            (context.config / "extract.sh").write_text("false\ntouch should-not-run\n")

            with self.assertRaisesRegex(CommandError, "Custom extraction failed"):
                MediaStager(context, config).extract()

            self.assertFalse((context.qemu_dir / "should-not-run").exists())
            self.assertFalse((context.qemu_dir / ".extracted").exists())

    def test_custom_extraction_script_preserves_staged_install_iso(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "guestlib").mkdir()
            context, config = temporary_config(
                root,
                "distro/version",
                {"extract": {"custom_script": "extract.sh"}},
            )
            (context.config / "extract.sh").write_text("touch install.iso\n")

            MediaStager(context, config).extract()

            self.assertTrue((context.qemu_dir / "install.iso").is_file())
            self.assertFalse((context.qemu_dir / "install.iso").is_symlink())

    def test_postprocessing_applies_overlays(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            context, config = temporary_config(root, "distro/version")
            context.qemu_dir.mkdir()
            config.download_dir.mkdir()
            (config.download_dir / "replacement.tgz").write_bytes(b"replacement")

            spec = Extraction(
                overlays=[
                    {
                        "source": "replacement.tgz",
                        "destination": "fat/packages/x2/x_svga.tgz",
                    }
                ],
            )
            MediaStager(context, config)._postprocess(spec)

            self.assertEqual(
                (context.qemu_dir / "fat/packages/x2/x_svga.tgz").read_bytes(),
                b"replacement",
            )

    def test_extraction_and_postinstall_schema_errors_are_rejected(self) -> None:
        context = SimpleNamespace(name="test")
        for table, message in (
            ({"extra_images": "boot.img"}, "array of strings"),
            ({"files": "README"}, "array of strings"),
            ({"package_dest": True}, "must be a string"),
            ({"unknown": True}, "Unknown extract"),
        ):
            with self.assertRaisesRegex(ConfigError, message):
                toml_extraction(RetroConfig(context=context, data={"extract": table}))
        for table, message in (
            ({"stages": ["mystery"]}, "Unknown post-install"),
            ({"stages": ["custom"]}, "requires postinst.custom_script"),
            ({"stages": [], "network": []}, "must be a table"),
        ):
            with self.assertRaisesRegex(ConfigError, message):
                RetroConfig(context=context, data={"postinst": table}).postinst

    def test_extraction_paths_cannot_escape_their_destination(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary) / "staging"
            directory.mkdir()
            with self.assertRaisesRegex(ConfigError, "escapes destination"):
                MediaStager._safe_child(directory, Path("../outside"))
            context = SimpleNamespace(extract_dir=directory)
            stager = MediaStager(context, SimpleNamespace())
            with self.assertRaisesRegex(ConfigError, "escapes destination"):
                stager._package_destination(Extraction(package_dest="../outside"))
            for source in ("../outside", "/outside"):
                with self.assertRaisesRegex(ConfigError, "escapes extraction source"):
                    MediaStager._validate_source_path(source)


class FdiskTests(unittest.TestCase):
    def test_range_parses_common_classic_fdisk_prompts(self) -> None:
        serial = unittest.mock.Mock()
        serial.wait.return_value = "First cylinder ([1]-[520], default 1): "
        driver = Fdisk(SimpleNamespace(serial=serial))
        self.assertEqual(driver._range("First cylinder"), (1, 520))

    def test_delete_partition_returns_whether_the_partition_exists(self) -> None:
        serial = unittest.mock.Mock()
        driver = Fdisk(SimpleNamespace(serial=serial))
        serial.wait_any.return_value = 0, "Partition number (1-4):"
        self.assertTrue(driver.delete_partition(2))
        self.assertEqual(serial.send.call_args_list, [call("d"), call("2")])

        serial.reset_mock()
        serial.wait_any.return_value = 1, "No partition is defined yet"
        self.assertFalse(driver.delete_partition(2))
        serial.send.assert_called_once_with("d")

    def test_print_and_write_table_send_fdisk_commands(self) -> None:
        serial = unittest.mock.Mock()
        driver = Fdisk(SimpleNamespace(serial=serial))
        driver.print_table()
        driver.write_table()
        self.assertEqual(serial.send.call_args_list, [call("p"), call("w")])

    def test_partition_swap_root_creates_swap_and_root_and_writes_table(self) -> None:
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
        Fdisk(session).partition_swap_root(swap_mb=32)
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
            context=SimpleNamespace(),
            data={
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
            context=SimpleNamespace(),
            data={
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
        fdisk.return_value.partition_swap_root.assert_called_once_with("/dev/sda", 32)
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
                    validate_install_config(RetroConfig(context=SimpleNamespace(), data=data))


class RedHatDriverTests(unittest.TestCase):
    def test_unattended_flow_boots_reboots_and_runs_postinstall(self) -> None:
        config = RetroConfig(
            context=SimpleNamespace(),
            data={
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
        redhat_c.run_unattended(session)
        self.assertEqual(session.vga_wait.call_args_list[0].args, ("boot:",))
        session.kb_type.assert_any_call("linux ks=floppy\n")
        session.set_boot.assert_called_once_with("c")
        session.run_postinst.assert_called_once_with("secret", login="login:", shell="#")

    def test_c_installer_composes_4x_phases_and_rejects_unknown_flow(self) -> None:
        session = SimpleNamespace(options=lambda _: redhat_c.CInstallerOptions(flow="4x"))
        installer = unittest.mock.Mock()
        installer.o.flow = "4x"
        with patch.object(redhat_c, "CInstaller", return_value=installer):
            redhat_c.run_c_installer(session)
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
        with patch.object(redhat_c, "CInstaller", return_value=installer):
            with self.assertRaisesRegex(ConfigError, "Unknown Red Hat C installer flow"):
                redhat_c.run_c_installer(session)

    def test_early_redhat_flow_composes_release_specific_phases(self) -> None:
        session = SimpleNamespace(
            config=RetroConfig(
                context=SimpleNamespace(),
                data={"install": {"redhat": {"flow": "1.1"}}},
            )
        )
        installer = unittest.mock.Mock()
        with patch.object(redhat_perl, "PerlInstaller", return_value=installer):
            redhat_perl.run_perl_installer(session)
        installer.boot.assert_called_once_with()
        installer.load_ramdisk.assert_called_once_with("rootdisk.img")
        installer.insert_boot_disk.assert_called_once_with()
        session.config = RetroConfig(
            context=SimpleNamespace(),
            data={"install": {"redhat": {"flow": "unknown"}}},
        )
        with patch.object(redhat_perl, "PerlInstaller", return_value=installer):
            with self.assertRaisesRegex(ConfigError, "Unknown Red Hat Perl installer flow"):
                redhat_perl.run_perl_installer(session)


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
    def test_filesystem_module_is_selected_from_its_menu(self) -> None:
        """Filesystem modules use the same Dinstall module workflow as network drivers."""
        dialog = unittest.mock.Mock()
        session = SimpleNamespace(
            dialog=dialog,
            vga_wait=unittest.mock.Mock(),
            kb_press=unittest.mock.Mock(),
        )
        driver = Dinstall(session, DinstallOptions(fs_module="vfat"))

        driver._modules("")

        module_choices = dialog.answer_until.call_args.args
        self.assertEqual(module_choices[0].answer, "fs")
        self.assertEqual(module_choices[1].answer, "vfat")
        self.assertEqual(module_choices[2].answer, "Install")
        self.assertEqual(module_choices[3].answer, "")
        session.vga_wait.assert_called_once_with(
            "Please press ENTER when you are ready to continue.", match=Match.LINE
        )
        session.kb_press.assert_called_once_with("ret")

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

    def test_package_prompts_are_answered_over_the_automation_serial_port(self) -> None:
        """Interactive package configuration stays on ttyS3 until postinst completes."""
        packages = DebianPackagesConfig.model_validate(
            {"prompts": [{"expect": "Configure package?", "answer": "yes"}]}
        )
        postinst = PostinstConfig(stages=["packages"], packages=packages)
        serial = unittest.mock.Mock()
        session = SimpleNamespace(
            config=SimpleNamespace(postinst=postinst),
            postinst_command="/retro/guestlib.d/postinst.sh",
            dialog=unittest.mock.Mock(),
            serial=serial,
            vga_wait=unittest.mock.Mock(),
            kb_type=unittest.mock.Mock(),
            serial_shell_start=unittest.mock.Mock(),
            serial_shell_send=unittest.mock.Mock(),
            serial_shell_exit=unittest.mock.Mock(),
        )

        Dinstall(session, DinstallOptions())._postinst()

        session.serial_shell_start.assert_called_once()
        session.serial_shell_send.assert_called_once_with(session.postinst_command, wait=False)
        serial.answer_any.assert_called_once_with([("Configure package?", "yes", False)])
        serial.wait.assert_called_once_with("Configuration complete!", line=True)
        session.serial_shell_exit.assert_called_once()

        session.config.postinst = PostinstConfig(
            stages=["packages", "tty"], packages=packages
        )
        session.serial_shell_exit.reset_mock()
        Dinstall(session, DinstallOptions())._postinst()
        session.serial_shell_exit.assert_not_called()


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
    def test_every_extraction_configuration_passes_schema_validation(self) -> None:
        root = Path(__file__).resolve().parent.parent
        validated = []
        for family in ("cdrom", "debian", "redhat", "slackware"):
            for path in (root / family).glob("**/config.toml"):
                context = Context(root, path.parent, "extract", root / "temporary")
                config = load_config(context)
                if config.section("extract"):
                    toml_extraction(config)
                    validated.append(path)
        self.assertEqual(len(validated), 51)

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
        self.assertEqual(len(validated), 62)

    def test_every_postinstall_configuration_passes_schema_validation(self) -> None:
        root = Path(__file__).resolve().parent.parent
        validated = []
        for family in ("debian", "redhat", "slackware"):
            for path in (root / family).glob("**/config.toml"):
                context = Context(root, path.parent, "extract", root / "temporary")
                config = load_config(context)
                if config.section("postinst"):
                    config.postinst
                    validated.append(path)
        self.assertEqual(len(validated), 62)

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
                "slackware/1.01/channel1",
                "slackware/1.01/official+sls",
                "slackware/1.0beta/official",
                "slackware/3.6/linuxmall",
                "debian/1.1/official",
                "debian/1.1/infomagic",
                "debian/1.1/oldfloss",
                "debian/1.2/official",
                "debian/1.2/infomagic",
                "debian/1.3/official",
                "debian/1.3/infomagic",
            },
        )

    def test_every_extract_shell_manifest_has_toml_extraction(self) -> None:
        root = Path(__file__).resolve().parent.parent
        for family in ("slackware", "redhat", "debian"):
            for script in (root / family).glob("**/extract.sh"):
                referenced = False
                for config_path in (root / family).glob("**/config.toml"):
                    context = Context.create(root, "extract", str(config_path.parent))
                    custom_script = load_config(context).section("extract").get("custom_script")
                    if custom_script and context.find(custom_script) == script:
                        referenced = True
                        break
                self.assertTrue(
                    referenced,
                    script.relative_to(root),
                )

    def test_every_distro_shell_script_is_referenced_by_toml(self) -> None:
        root = Path(__file__).resolve().parent.parent
        referenced = set()
        for path in root.glob("**/config.toml"):
            context = Context.create(root, "extract", str(path.parent))
            config = load_config(context)
            for section in ("extract", "postinst"):
                script = config.section(section).get("custom_script")
                if script:
                    referenced.add(context.find(script))
        scripts = {
            path.resolve()
            for family in ("slackware", "redhat", "debian", "cdrom")
            for path in (root / family).glob("**/*.sh")
            if "qemu.d" not in path.parts and "download.d" not in path.parts
        }
        self.assertEqual(scripts, referenced)

    def test_custom_extraction_scripts_contain_actions_not_configuration(self) -> None:
        root = Path(__file__).resolve().parent.parent
        for script in (root / "slackware").glob("**/extract.sh"):
            contents = script.read_text()
            self.assertNotIn("EXTRACT_", contents, script.relative_to(root))
            self.assertNotIn("extract_install", contents, script.relative_to(root))

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

    def test_only_supported_non_iso_declarative_sources_are_used(self) -> None:
        root = Path(__file__).resolve().parent.parent
        archives = []
        for path in root.glob("**/config.toml"):
            extract = tomllib.loads(path.read_text()).get("extract", {})
            source = extract.get("source", "")
            if source and not source.lower().endswith(".iso"):
                archives.append(path.relative_to(root))
        archives.sort()
        self.assertEqual(
            archives,
            [
                Path("debian/1.1/oldfloss/config.toml"),
                Path("slackware/1.01/channel1/config.toml"),
                Path("slackware/1.01/official+sls/config.toml"),
                Path("slackware/1.0beta/official+sls/config.toml"),
                Path("slackware/3.6/linuxmall/config.toml"),
            ],
        )

    def test_legacy_install_shell_manifests_are_removed(self) -> None:
        root = Path(__file__).resolve().parent.parent
        scripts = (
            script
            for family in ("slackware", "redhat", "debian")
            for script in (root / family).glob("**/install.sh")
        )
        self.assertEqual(list(scripts), [])

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

    def test_canonical_media_link_rejects_a_missing_source(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / "boot.img"
            with self.assertRaisesRegex(ConfigError, "Link source not found: missing.img"):
                MediaStager._link("missing.img", destination)


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

    async def test_partial_serial_prompt_is_echoed_as_one_line(self) -> None:
        """Unconfigured package questions remain visible without chunk splitting."""
        console = SerialConsole(Path("unused.sock"))
        console._buffer = "Question without newline? [No] "
        with self.assertLogs("hostlib.serial", "INFO") as transcript:
            console._flush_partial_echo()
        self.assertTrue(
            any("➡️  Question without newline? [No]" in line for line in transcript.output)
        )

    async def test_completed_serial_lines_are_marked_while_they_arrive(self) -> None:
        """An active waiter marks its matching line without delaying other output."""
        console = SerialConsole(Path("unused.sock"))
        console._echo_patterns = (re.compile("expected"),)
        console._buffer = "ordinary line\nexpected prompt\n"
        with self.assertLogs("hostlib.serial", "INFO") as transcript:
            console._emit_transcript(len(console._buffer))
        self.assertTrue(any("➡️  ordinary line" in line for line in transcript.output))
        self.assertTrue(any("✅ expected prompt" in line for line in transcript.output))

    async def test_rewind_does_not_replay_already_echoed_serial_output(self) -> None:
        """Dialog callbacks may reread a screen without duplicating transcript lines."""
        console = SerialConsole(Path("unused.sock"))
        console._buffer = "dialog screen\n"
        with self.assertLogs("hostlib.serial", "INFO") as transcript:
            console._emit_transcript(len(console._buffer))
            await console.rewind(0)
            console._emit_transcript(len(console._buffer))
        self.assertEqual(sum("dialog screen" in line for line in transcript.output), 1)


class SessionTests(unittest.TestCase):
    def session(self, install=None, postinst=None):
        runtime = SimpleNamespace(
            monitor=AsyncMock(),
            vga=SimpleNamespace(wait=AsyncMock(), invalidate=unittest.mock.Mock()),
        )
        session = InstallSession(
            runtime,
            None,
            RetroConfig(
                context=SimpleNamespace(),
                data={"install": install or {}, "postinst": postinst or {}},
            ),
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
            {
                "disk": {
                    "fat_partition": "/dev/sdb1",
                    "fat_mount": "/media/retro",
                    "fat_filesystem": "vfat",
                }
            }
        )
        self.assertIn("mount -t vfat", session.postinst_command)
        self.assertIn("/dev/sdb1 /media/retro", session.postinst_command)
        self.assertIn("/media/retro/guestlib.d/postinst.sh", session.postinst_command)

    def test_postinstall_can_use_a_different_fat_filesystem(self) -> None:
        session = self.session(postinst={"fat_filesystem": "vfat"})
        self.assertIn("mount -t vfat", session.postinst_command)


if __name__ == "__main__":
    unittest.main()
