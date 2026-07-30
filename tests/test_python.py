from __future__ import annotations

import asyncio
import ast
from contextlib import contextmanager
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

from hostlib.config import QemuConfig, RetroConfig, load_config
from hostlib.context import Context
from hostlib.errors import CommandError, ConfigError, RetroError
from hostlib import cli, download, operations, qmp_cli, tagfiles
from hostlib.fdisk import Fdisk
from hostlib.keyboard import encode
from hostlib.dialog import Answer, AnswerText, AnswerTitle, Dialog
from hostlib.debian_packages import (
    DebianPackage,
    load_packages,
    render_installer,
    resolve_packages,
)
from hostlib.session import InstallSession, Match
from hostlib.serial import SerialConsole
from hostlib.installers.slackware import Pkgtool, boot_pkgtool
from hostlib.installers.debian import Dinstall
from hostlib.installers.slackware_sysinstall import Sysinstall
from hostlib.installers import (
    STEP_HANDLERS,
    run_configured_install,
    validate_install_config,
)
from hostlib import installers
from hostlib.installers import redhat_dialog, redhat_newt
from hostlib.newt_dialog import NewtDialog, parse_dialog
from hostlib.vga import ScreenBounds, ScreenObserver, ScreenSnapshot
from hostlib.media import MediaStager
from hostlib.media_schemas import DebianPackagesConfig, ExtractionConfig, PostinstConfig
from hostlib.schemas import (
    DinstallInstallConfig,
    PkgtoolInstallConfig,
    SysinstallInstallConfig,
)
from hostlib.qmp import Monitor
from hostlib.qemu import QemuRuntime


@contextmanager
def temporary_root():
    """Yield a temporary repository root as a path."""
    with tempfile.TemporaryDirectory() as directory:
        yield Path(directory)


def temporary_config(
    root: Path, name: str, data: dict | None = None
) -> tuple[Context, RetroConfig]:
    """Create a minimal config and context beneath a temporary repository."""
    (root / "guestlib").mkdir(exist_ok=True)
    directory = root / name
    directory.mkdir(parents=True)
    context = Context(root, directory, "boot", root / "temporary")
    context.temporary.mkdir(exist_ok=True)
    return context, RetroConfig(context=context, data=data or {})


def dinstall_config(**values: object) -> DinstallInstallConfig:
    return DinstallInstallConfig.model_validate({"driver": "debian-dinstall", **values})


def pkgtool_config(**values: object) -> PkgtoolInstallConfig:
    return PkgtoolInstallConfig.model_validate({"driver": "slackware-pkgtool", **values})


def sysinstall_config(**values: object) -> SysinstallInstallConfig:
    return SysinstallInstallConfig.model_validate({"driver": "slackware-sysinstall", **values})


def package(
    name: str,
    *,
    priority: str = "optional",
    section: str = "base",
    filename: str | None = None,
    **fields: str,
) -> DebianPackage:
    """Build a compact Debian package record for dependency tests."""
    return DebianPackage(
        {
            "package": name,
            "priority": priority,
            "section": section,
            "filename": filename or f"{section}/{name}.deb",
            **fields,
        }
    )


class ContextTests(unittest.TestCase):
    def test_find_prefers_selected_config_then_parent(self) -> None:
        with temporary_root() as root:
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
        config = SimpleNamespace(qemu=QemuConfig())
        with (
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
        with temporary_root() as root:
            context, config = temporary_config(root, "distro/version")
            context.qemu_dir.mkdir()
            with patch("builtins.input", return_value="no"):
                cli.Application(context, config).reset()
            self.assertTrue(context.qemu_dir.exists())
            with patch("builtins.input", return_value="yes"):
                cli.Application(context, config).reset()
            self.assertFalse(context.qemu_dir.exists())

    def test_run_main_always_removes_the_context_temporary_directory(self) -> None:
        with temporary_root() as root:
            scratch = root / "command-temp"
            scratch.mkdir()
            context = SimpleNamespace(command="help", name="test", temporary=scratch, config=root)
            with (
                patch.object(cli.Context, "create", return_value=context),
                patch.object(cli, "load_config", return_value=SimpleNamespace()),
                patch.object(cli.Application, "run", side_effect=ConfigError("broken")),
            ):
                with self.assertRaisesRegex(ConfigError, "broken"):
                    cli.run_main(["help"])
            self.assertFalse(scratch.exists())

    def test_installer_failure_releases_monitor_and_leaves_vm_for_inspection(self) -> None:
        process = SimpleNamespace(returncode=None, terminate=unittest.mock.Mock())

        async def wait():
            process.returncode = 0
            return 0

        process.wait = AsyncMock(side_effect=wait)
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
            with self.assertLogs("hostlib.cli", level="ERROR") as captured:
                asyncio.run(app._run_vm(QemuConfig(), install=True))
        self.assertIn("Installer automation failed", "\n".join(captured.output))
        self.assertIn("RetroError: install failed", "\n".join(captured.output))
        monitor.close.assert_awaited_once_with()
        process.terminate.assert_not_called()
        process.wait.assert_awaited_once_with()

    def test_plain_boot_releases_monitor_for_qmp_cli(self) -> None:
        process = SimpleNamespace(returncode=0, wait=AsyncMock(return_value=0))
        monitor = SimpleNamespace(close=AsyncMock())
        runtime = SimpleNamespace(
            start=AsyncMock(return_value=process),
            connect_monitor=AsyncMock(return_value=monitor),
        )
        app = cli.Application(SimpleNamespace(qemu_dir=Path("qemu.d")), SimpleNamespace())
        with patch.object(cli, "QemuRuntime", return_value=runtime):
            asyncio.run(app._run_vm(QemuConfig(), install=False))
        monitor.close.assert_awaited_once_with()


class DownloadTests(unittest.TestCase):
    def test_direct_download_creates_nested_path_and_skips_existing_file(self) -> None:
        with temporary_root() as root:
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
        with temporary_root() as root:
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
        with temporary_root() as root:
            target = root / "disk.img"
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
        with temporary_root() as root:
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
                patch.object(downloader.wget, "retrieve"),
                patch.object(downloader.wget, "mirror") as mirror,
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
        with temporary_root() as root:
            destination = root / "release"
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
        with temporary_root() as root:
            destination = root / "release"
            destination.mkdir()
            (destination / download.Wget.MIRROR_SENTINEL).touch()
            with (
                patch("hostlib.download.subprocess.run") as wget,
                self.assertLogs(download.log, "INFO") as logs,
            ):
                download.Wget().mirror("https://x/releases/tree/", destination, ("*index*",))
            wget.assert_not_called()
            self.assertEqual(
                logs.output,
                [
                    "INFO:hostlib.download:Skipping completed download; remove "
                    f"{os.path.relpath(destination / download.Wget.MIRROR_SENTINEL)} to retry",
                ],
            )

    def test_failed_recursive_mirror_is_not_marked_complete(self) -> None:
        with temporary_root() as root:
            destination = root / "release"
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
        with temporary_root() as root:
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
    def test_dump_screen_rejects_an_invalid_timeout(self) -> None:
        with (
            patch("sys.stderr", io.StringIO()),
            self.assertRaises(SystemExit),
        ):
            qmp_cli._parser().parse_args(["dump-screen", "--timeout", "nan"])

    async def test_dump_screen_uses_a_qemu_relative_raw_dump(self) -> None:
        with temporary_root() as root:
            monitor = AsyncMock()
            socket = root / "qmp.sock"
            socket.touch()

            async def write_dump(command: str) -> None:
                (root / command.split()[-1]).write_bytes(b"A\x07" + b" \x07" * 79)

            monitor.hmp.side_effect = write_dump
            with patch("sys.stdout", io.StringIO()) as output:
                await qmp_cli._dump_screen(monitor, socket)
            self.assertTrue(output.getvalue().startswith("A"))
            self.assertFalse(monitor.hmp.await_args.args[0].split()[-1].startswith("/"))

    async def test_socket_resolution_and_control_commands(self) -> None:
        with temporary_root() as root:
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


class SlackwareTagfileTests(unittest.TestCase):
    def test_package_names_remove_only_slackware_version_suffixes(self) -> None:
        self.assertEqual(tagfiles._package_name("bash-1.14.7-i386-1.tgz"), "bash")
        self.assertEqual(tagfiles._package_name("kernel.tgz"), "kernel")

    def test_prepare_tagfiles_applies_exact_rules_over_series_defaults(self) -> None:
        with temporary_root() as root:
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
        with temporary_root() as root:
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
    def test_qemu_config_retains_only_distro_controls(self) -> None:
        config = QemuConfig(
            profile="linux-2.0",
            disk={"size": "2G"},
            network={"device": "pcnet"},
            serial={"auxiliary": "msmouse"},
        )
        self.assertEqual(config.profile, "linux-2.0")
        self.assertEqual(config.disk.size, "2G")
        self.assertEqual(config.network.device, "pcnet")
        self.assertEqual(config.serial.auxiliary, "msmouse")

    def test_toml_inherits_parent_tables_and_replaces_arrays(self) -> None:
        with temporary_root() as root:
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
        with temporary_root() as root:
            directory = root / "distro/version"
            directory.mkdir(parents=True)
            (directory / "config.toml").write_text(
                '[qemu]\nprofile = "linux-2.0"\n'
                '[qemu.network]\ndevice = "pcnet"\n'
                '[extract]\nsource = "disc1.iso"\nboot_image = "images/boot.img"\n'
                'package_source = "slakware"\n'
            )
            context = Context.create(root, "boot", str(directory))
            qemu = load_config(context).qemu
            extraction = load_config(context).extraction
            self.assertEqual(qemu.profile, "linux-2.0")
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
            config.qemu

    def test_installer_options_are_collected_from_logical_tables(self) -> None:
        with temporary_root() as root:
            directory = root / "debian/1.1"
            directory.mkdir(parents=True)
            (directory / "config.toml").write_text(
                '[install]\ndriver = "debian-dinstall"\n'
                '[install.network]\nhostname = "buzz"\n'
                'domain = "example.test"\nip = "192.0.2.15"\n'
                "[install.debian]\ndriver_floppy = false\nrelogin = true\n"
            )
            context = Context.create(root, "install", str(directory))
            config = load_config(context)
            install = config.install
            validate_install_config(config)
            self.assertIsInstance(install, DinstallInstallConfig)
            assert isinstance(install, DinstallInstallConfig)
            self.assertEqual(install.network.hostname, "buzz")
            self.assertEqual(install.network.domain, "example.test")
            self.assertEqual(install.network.ip, "192.0.2.15")
            self.assertFalse(install.debian.driver_floppy)
            self.assertTrue(install.debian.relogin)

    def test_nested_installer_option_errors_use_the_config_error_boundary(self) -> None:
        config = RetroConfig(
            context=SimpleNamespace(),
            data={"install": {"driver": "debian-dinstall", "network": {"ip": 123}}},
        )
        with self.assertRaisesRegex(ConfigError, "install.network.ip must be a string"):
            _ = config.install

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

    def test_postinstall_network_renders_guest_variable_names(self) -> None:
        settings = RetroConfig(
            context=SimpleNamespace(),
            data={
                "postinst": {
                    "stages": ["network"],
                    "network": {
                        "hostname": "retro",
                        "domain": "example.test",
                        "ip": "192.0.2.15",
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
        with temporary_root() as root:
            runtime = self.runtime(root)
            with patch("hostlib.qemu.available_port", side_effect=[2200, 2300]) as port:
                command = runtime.command()
                runtime.command()

            netdev = command[command.index("-netdev") + 1]
            self.assertIn("hostfwd=tcp:127.0.0.1:2200-:22", netdev)
            self.assertIn("hostfwd=tcp:127.0.0.1:2300-:23", netdev)
            self.assertEqual([call.args[0] for call in port.call_args_list], [2200, 2300])

    def test_explicit_empty_forward_list_disables_port_forwards(self) -> None:
        with temporary_root() as root:
            runtime = self.runtime(root, QemuConfig(network={"forwards": []}))
            netdev = runtime.command()[runtime.command().index("-netdev") + 1]
            self.assertEqual(netdev, "user,id=internet")

    def test_auxiliary_serial_backend_occupies_guest_ttys2(self) -> None:
        with temporary_root() as root:
            runtime = self.runtime(root, QemuConfig(serial={"auxiliary": "msmouse"}))
            serials = [value for option, value in runtime._chardevs() if option == "-serial"]
            self.assertEqual(serials[2], "msmouse")
            self.assertIn("ttyS3.sock", serials[3])

    def test_device_report_includes_endpoints_disks_and_character_sockets(self) -> None:
        with temporary_root() as root:
            runtime = self.runtime(root, QemuConfig(network={"forwards": [[2200, 22]]}))
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
        with temporary_root() as root:
            runtime = self.runtime(root)
            (runtime.directory / "boot.img").unlink()
            with self.assertRaisesRegex(CommandError, "No bootable devices"):
                runtime.ensure_disk()
            (runtime.directory / "boot.img").touch()
            with patch("hostlib.qemu.subprocess.run", return_value=SimpleNamespace(returncode=1)):
                with self.assertRaisesRegex(CommandError, "Could not create"):
                    runtime.ensure_disk()

    def test_drives_include_floppy_cdrom_fat_and_disk(self) -> None:
        with temporary_root() as root:
            runtime = self.runtime(root)
            (runtime.directory / "hda.img").touch()
            (runtime.directory / "install.iso").touch()
            (runtime.directory / "fat").mkdir()
            drives = runtime._drives()
            rendered = "\n".join(drives)
            self.assertIn("file=boot.img", rendered)
            self.assertIn("file=hda.img", rendered)
            self.assertIn("media=cdrom,file=install.iso", rendered)
            self.assertIn("file=fat:rw:fat", rendered)


class QemuLifecycleTests(unittest.IsolatedAsyncioTestCase):
    async def test_start_removes_stale_sockets_and_uses_qemu_directory(self) -> None:
        with temporary_root() as root:
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
            self.assertEqual(create.await_args.args[0], "qemu-system-i386")


class DebianPackageTests(unittest.TestCase):
    def test_packages_parser_accepts_lowercase_fields_continuations_and_gzip(self) -> None:
        """Debian's control format and compressed indexes retain every field."""
        contents = (
            "Package: demo\npriority: optional\nsection: utils\n"
            "description: first line\n second line\nfilename: pool/demo_1.deb\n\n"
        )
        with temporary_root() as root:
            source = root / "Packages.gz"
            with gzip.open(source, "wt") as output:
                output.write(contents)
            packages = load_packages(source)
            self.assertEqual(packages[0].fields["description"], "first line\nsecond line")
            self.assertEqual(packages[0].name, "demo")

    def test_dependency_resolution_supports_versions_alternatives_and_providers(self) -> None:
        """Dependencies precede selected users and virtual packages resolve to providers."""
        packages = [
            package("lib", priority="required"),
            package("mailer", section="mail", provides="mail-transport-agent"),
            package("app", section="utils", depends="lib (>= 1), missing | mail-transport-agent"),
        ]
        selected = resolve_packages(packages, DebianPackagesConfig(add=["app"]))
        self.assertEqual([package.name for package in selected], ["lib", "mailer", "app"])

    def test_skip_prevents_dependency_installation(self) -> None:
        """Skipping a required dependency reports an unresolved selection."""
        packages = [
            package("library", section="libs"),
            package("application", section="utils", depends="library"),
        ]
        with self.assertRaisesRegex(ConfigError, "Unresolved dependency"):
            resolve_packages(packages, DebianPackagesConfig(add=["application"], skip=["library"]))

    def test_global_and_per_section_priorities_are_combined(self) -> None:
        """Section priorities override global priorities in their own section."""
        packages = [
            package("base", priority="required"),
            package("editor", section="editors"),
            package("editor-extra", priority="extra", section="editors"),
            package("game", priority="extra", section="games"),
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
            package("base", priority="required"),
            package("editor", section="editors"),
        ]
        config = DebianPackagesConfig(
            priorities=["required"],
            sections={"editors": ["optional"]},
            add=["editor"],
            skip=["base", "editor"],
        )
        self.assertEqual([package.name for package in resolve_packages(packages, config)], [])

    def test_explicit_packages_precede_priority_selections(self) -> None:
        """Explicit prerequisites install before packages selected by priority."""
        packages = [
            package("zlib", priority="standard", section="devel"),
            package("perl", priority="important", section="devel"),
        ]
        config = DebianPackagesConfig(priorities=["important"], add=["zlib"])
        self.assertEqual(
            [package.name for package in resolve_packages(packages, config)],
            ["zlib", "perl"],
        )

    def test_installer_mounts_iso_and_uses_long_filenames(self) -> None:
        """CD-backed scripts mount the device and derive paths from Filename basenames."""
        selected = package(
            "demo",
            section="utils",
            filename="Debian/binary-i386/utils/demo_1.2-3.deb",
            **{"msdos-filename": "Debian/msdos-i386/utils/demo.deb"},
        )
        config = DebianPackagesConfig.model_validate(
            {
                "roots": ["/cdrom/buzz-fixed/binary-i386", "/cdrom/buzz/binary-i386"],
                "mount": {"device": "/dev/hdc", "point": "/cdrom"},
            }
        )
        script = render_installer([selected], config)
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
        with temporary_root() as root:
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
            self.assertIn("retro_dpkg_install 'utils' 'demo_1.deb'", installer.read_text())
            self.assertTrue((context.qemu_dir / ".extracted").exists())

    def test_existing_marker_refreshes_guestlib_without_reextracting(self) -> None:
        with temporary_root() as root:
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
        with temporary_root() as root:
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
        with temporary_root() as root:
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
        with temporary_root() as root:
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
        with temporary_root() as root:
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
        with temporary_root() as root:
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
        with temporary_root() as root:
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
        with temporary_root() as root:
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
        with temporary_root() as root:
            context, config = temporary_config(root, "distro/version")
            context.qemu_dir.mkdir()
            config.download_dir.mkdir()
            (config.download_dir / "replacement.tgz").write_bytes(b"replacement")

            spec = ExtractionConfig(
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
                _ = RetroConfig(context=context, data={"extract": table}).extraction
        for table, message in (
            ({"stages": ["mystery"]}, "Unknown post-install"),
            ({"stages": ["custom"]}, "requires postinst.custom_script"),
            ({"stages": [], "network": []}, "must be a table"),
        ):
            with self.assertRaisesRegex(ConfigError, message):
                RetroConfig(context=context, data={"postinst": table}).postinst

    def test_extraction_paths_cannot_escape_their_destination(self) -> None:
        with temporary_root() as root:
            directory = root / "staging"
            directory.mkdir()
            with self.assertRaisesRegex(ConfigError, "escapes destination"):
                MediaStager._safe_child(directory, Path("../outside"))
            with self.assertRaisesRegex(ConfigError, "escapes destination"):
                MediaStager._selected_archive_members(
                    ["../outside"], ExtractionConfig(files=["*"]), ["*"]
                )
            context = SimpleNamespace(qemu_dir=directory)
            stager = MediaStager(context, SimpleNamespace())
            with self.assertRaisesRegex(ConfigError, "escapes destination"):
                stager._package_destination(ExtractionConfig(package_dest="../outside"))
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
            def wait(self, expected, regex=False, line=False):
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
        with temporary_root() as root:
            directory = root / "distro/version"
            directory.mkdir(parents=True)
            (directory / "config.toml").write_text(
                '[install]\ndriver = "prompt-sequence"\n'
                '[install.network]\nhostname = "retro"\n'
                '[[install.steps]]\naction = "type"\n'
                'text = "${install.network.hostname}\\n"\n'
                '[[install.steps]]\naction = "press"\nkeys = "f12"\n'
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
            {"action": "wait", "text": "Ready", "match": "line"},
            {"action": "wait", "transport": "serial", "text": "login:", "match": "regex"},
            {"action": "type", "text": "${install.network.hostname}\n"},
            {"action": "press", "keys": ["tab", "ret"], "repeat": 2},
            {
                "action": "prompt",
                "transport": "serial",
                "questions": ["one", "two"],
                "answer": "yes",
                "regex": True,
            },
            {
                "action": "prompt",
                "questions": ["screen one", "screen two"],
                "answer": "ok",
                "regex": True,
            },
            {"action": "serial-shell-start", "screen_prompt": "$", "serial_prompt": "#"},
            {"action": "serial-shell-send", "command": "setup", "wait": False, "prompt": "$"},
            {
                "action": "serial-shell-send",
                "command": ['echo "${install.network.hostname}"', "echo done"],
                "prompt": "$",
            },
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
                    "default_transport": "vga",
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
        self.assertEqual(
            session.vga_wait.call_args_list,
            [
                call("Ready", match=Match.LINE, timeout=None),
                call("screen one", "screen two", match=Match.REGEX),
            ],
        )
        serial.wait.assert_called_once_with("login:", line=False, regex=True, timeout=None)
        self.assertEqual(session.kb_type.call_args_list, [call("retro\n"), call("ok\n")])
        self.assertEqual(session.kb_press.call_count, 2)
        serial.prompt.assert_called_once_with("one", "two", answer="yes", regex=True)
        session.serial_shell_start.assert_called_once_with(screen_prompt="$", serial_prompt="#")
        self.assertEqual(
            session.serial_shell_send.call_args_list,
            [
                call("setup", wait=False, prompt="$"),
                call('echo "retro"', wait=True, prompt="$"),
                call("echo done", wait=True, prompt="$"),
            ],
        )
        session.serial_shell_exit.assert_called_once_with(screen_prompt="done")
        fdisk.return_value.partition_swap_root.assert_called_once_with("/dev/sda", 32)
        session.run_postinst.assert_called_once_with("secret", login="login:", shell="#")

    def test_prompt_sequence_preserves_transport_defaults_without_override(self) -> None:
        config = RetroConfig(
            context=SimpleNamespace(),
            data={
                "install": {
                    "driver": "prompt-sequence",
                    "steps": [
                        {"action": "wait", "text": "screen"},
                        {"action": "prompt", "questions": ["serial"], "answer": "yes"},
                    ],
                }
            },
        )
        wait, prompt = config.prompt_sequence.steps
        self.assertEqual(wait.transport, "vga")
        self.assertEqual(prompt.transport, "serial")

    def test_prompt_sequence_applies_default_action_before_transport(self) -> None:
        config = RetroConfig(
            context=SimpleNamespace(),
            data={
                "install": {
                    "driver": "prompt-sequence",
                    "default_action": "prompt",
                    "default_transport": "vga",
                    "steps": [{"questions": ["Continue?"], "answer": "y"}],
                }
            },
        )
        (prompt,) = config.prompt_sequence.steps
        self.assertEqual(prompt.action, "prompt")
        self.assertEqual(prompt.transport, "vga")

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
            (
                {"install": {"driver": "redhat-c", "redhat": {}}},
                "install.redhat.components is required",
            ),
            (
                {
                    "install": {
                        "driver": "redhat-c",
                        "redhat": {
                            "components": [],
                            "partitioning": "unknown",
                            "mouse_setup": "configure-mouse",
                            "x11_setup": "choose-card",
                            "tcp_ip_form": "gateway-and-nameserver",
                        },
                    }
                },
                "partitioning Input should be 'partition-disks'",
            ),
            (
                {"install": {"driver": "redhat-perl", "redhat": {"flow": "2.1"}}},
                "install.redhat.package_series is required",
            ),
            (
                {
                    "install": {
                        "driver": "redhat-perl",
                        "redhat": {"flow": "unknown", "package_series": []},
                    }
                },
                "install.redhat.flow must be one of: 1.1, 2.1, 3.0.3",
            ),
        )
        for data, message in cases:
            with self.subTest(message=message):
                with self.assertRaisesRegex(ConfigError, message):
                    validate_install_config(RetroConfig(context=SimpleNamespace(), data=data))


class RedHatDriverTests(unittest.TestCase):
    def test_c_installer_configs_select_explicit_screen_workflows(self) -> None:
        root = Path(__file__).resolve().parent.parent
        expected = {
            "4.0-infomagic": (
                "partition-disks",
                "configure-mouse",
                "choose-card",
                "direct",
                "network-and-broadcast",
            ),
            "4.1-infomagic": (
                "partition-disks",
                "configure-mouse",
                "choose-card",
                "direct",
                "gateway-and-nameserver",
            ),
            "4.2-infomagic": (
                "partition-disks",
                "configure-mouse",
                "choose-card",
                "direct",
                "gateway-and-nameserver",
            ),
            "5.0-infomagic": (
                "select-root-partition",
                "probe-and-emulation",
                "pci-probe",
                "direct",
                "gateway-and-nameserver",
            ),
            "5.1-infomagic": (
                "current-disk-partitions",
                "probe-and-configure-mouse",
                "pci-probe",
                "probe-static",
                "gateway-and-nameserver",
            ),
        }
        for release, workflows in expected.items():
            with self.subTest(release=release):
                context = Context.create(root, "install", f"redhat/{release}")
                settings = load_config(context).install.redhat
                self.assertEqual(
                    (
                        settings.partitioning,
                        settings.mouse_setup,
                        settings.x11_setup,
                        settings.network_setup,
                        settings.tcp_ip_form,
                    ),
                    workflows,
                )

    def test_c_installer_configs_declare_exact_component_sets(self) -> None:
        root = Path(__file__).resolve().parent.parent
        expected = {
            "4.0-infomagic": [
                "C Development",
                "C++ Development",
                "Print Server",
                "Game Machine",
                "Multimedia Machine",
                "X Window System",
                "X Development",
                "X multimedia support",
                "Extra Documentation",
            ],
            "4.1-infomagic": [
                "C Development",
                "C++ Development",
                "Print Server",
                "Game Machine",
                "Multimedia Machine",
                "X Window System",
                "X Development",
                "X multimedia support",
                "Extra Documentation",
            ],
            "4.2-infomagic": [
                "C Development",
                "C++ Development",
                "Printer Support",
                "Dialup Workstation",
                "Game Machine",
                "Multimedia Machine",
                "X Window System",
                "X Development",
            ],
            "5.0-infomagic": [
                "X Window System",
                "Mail/WWW/News Tools",
                "File Managers",
                "X multimedia support",
                "Console Multimedia",
                "Networked Workstation",
                "Dialup Workstation",
            ],
            "5.1-infomagic": [
                "X Window System",
                "Mail/WWW/News Tools",
                "File Managers",
                "X multimedia support",
                "Console Multimedia",
                "Networked Workstation",
                "Dialup Workstation",
            ],
        }
        for release, components in expected.items():
            with self.subTest(release=release):
                context = Context.create(root, "install", f"redhat/{release}")
                install = load_config(context).install
                self.assertEqual(install.redhat.components, components)

    def test_c_installer_configs_use_source_field_labels(self) -> None:
        root = Path(__file__).resolve().parent.parent
        expected = {
            "4.0-infomagic": ("Password        :", "Boot label :"),
            "4.1-infomagic": ("Password        :", "Boot label :"),
            "4.2-infomagic": ("Password        :", "Boot label :"),
            "5.0-infomagic": ("Password        :", "Boot label :"),
            "5.1-infomagic": ("Password:", "Boot label:"),
        }
        for release, labels in expected.items():
            with self.subTest(release=release):
                context = Context.create(root, "install", f"redhat/{release}")
                settings = load_config(context).install.redhat
                self.assertEqual(
                    (settings.password_field, settings.boot_label_field),
                    labels,
                )

    def test_later_c_installer_configs_encode_source_specific_controls(self) -> None:
        root = Path(__file__).resolve().parent.parent
        expected = {
            "4.1-infomagic": {
                "timezone": "UTC",
                "lilo_setup_dialogs": 2,
                "lilo_boot_labels": True,
                "x_video_memory_label": "2048",
            },
            "4.2-infomagic": {
                "timezone": "Etc/UTC",
                "lilo_setup_dialogs": 2,
                "lilo_boot_labels": True,
                "x_video_memory_label": "2048",
            },
            "5.0-infomagic": {
                "timezone": "Etc/UTC",
                "lilo_setup_dialogs": 2,
                "lilo_boot_labels": True,
                # Xconfigurator 3.25 stores 2048 internally but renders the
                # corresponding wangermemorys entry as "2 meg".
                "x_video_memory_label": "2 meg",
            },
            "5.1-infomagic": {
                "timezone": "Etc/UTC",
                "lilo_setup_dialogs": 2,
                "lilo_boot_labels": True,
                "x_video_memory_label": "2 meg",
                "password_field": "Password:",
                "boot_label_field": "Boot label:",
            },
        }
        for release, controls in expected.items():
            with self.subTest(release=release):
                context = Context.create(root, "install", f"redhat/{release}")
                install = load_config(context).install
                self.assertEqual(
                    install.locale.timezone,
                    controls["timezone"],
                )
                self.assertEqual(install.disk.root_partition, "/dev/hda2")
                self.assertEqual(install.disk.fat_partition, "/dev/hdb1")
                self.assertEqual(
                    install.redhat.timezone_clock_control,
                    "checkbox",
                )
                for name, value in controls.items():
                    if name == "timezone":
                        continue
                    self.assertEqual(getattr(install.redhat, name), value)

    def test_redhat_dialog_combines_common_flow_and_dispatches_optional_dialogs(self) -> None:
        installer = object.__new__(redhat_dialog.PerlInstaller)
        installer.load_two_ramdisks = unittest.mock.Mock()
        installer.prepare_dialog = unittest.mock.Mock()
        installer.insert_boot_disk = unittest.mock.Mock()
        installer._choose_text_cdrom = unittest.mock.Mock()
        installer.partition = unittest.mock.Mock()
        installer.dismiss_swap_error = unittest.mock.Mock()
        installer.configure_network = unittest.mock.Mock()
        installer.format_root = unittest.mock.Mock()
        installer._finish = unittest.mock.Mock()
        installer.dialog = unittest.mock.Mock()
        installer.settings = SimpleNamespace(
            flow="3.0.3",
            package_series=["Networking", "X Windows"],
        )

        installer.install("first dialog", x_vga=True)

        installer.load_two_ramdisks.assert_called_once_with()
        installer.prepare_dialog.assert_called_once_with("first dialog")
        self.assertEqual(
            [
                [(choice.title, choice.answer, choice.exit) for choice in call.args]
                for call in installer.dialog.answer_until.call_args_list
            ],
            [
                [
                    ("Color Screen", "yes", False),
                    ("Boot Floppy", None, True),
                ],
                [
                    ("Select Packages", "no", False),
                    ("Package Installation", "ok", False),
                    ("Mouse Configuration", None, True),
                ],
            ],
        )
        answers = [call.args[0] for call in installer.dialog.answer.call_args_list]
        self.assertEqual(
            [(answer.widget, answer.title, answer.answer) for answer in answers],
            [
                ("yesno", "Add Swap", "yes"),
                ("yesno", "Success", "yes"),
                (
                    "checklist",
                    "Select Series",
                    ("Networking", "X Windows"),
                ),
                ("menu", "X Configuration", "SVGA"),
            ],
        )
        installer.dismiss_swap_error.assert_called_once_with()
        installer._finish.assert_called_once_with(x_vga=True)

    def test_unattended_flow_boots_reboots_and_runs_postinstall(self) -> None:
        config = RetroConfig(
            context=SimpleNamespace(),
            data={
                "install": {
                    "driver": "redhat-unattended",
                    "accounts": {"root_password": "secret"},
                    "prompts": {"login_prompt": "login:", "shell_prompt": "#"},
                    "boot": {"prompt": "boot:", "command": "linux ks=floppy"},
                    "completion": {"prompt": "Complete", "reboot": True, "postinst": True},
                }
            },
        )
        session = SimpleNamespace(
            config=config,
            boot_command=unittest.mock.Mock(),
            vga_wait=unittest.mock.Mock(),
            kb_type=unittest.mock.Mock(),
            set_boot=unittest.mock.Mock(),
            run_postinst=unittest.mock.Mock(),
        )
        redhat_newt.run_unattended(session)
        session.boot_command.assert_called_once_with("boot:", "linux ks=floppy")
        session.vga_wait.assert_called_once_with("Complete")
        session.set_boot.assert_called_once_with("c")
        session.run_postinst.assert_called_once_with("secret", login="login:", shell="#")

    def test_c_installer_composes_explicit_phases(self) -> None:
        session = SimpleNamespace()
        installer = unittest.mock.Mock()
        with patch.object(redhat_newt, "CInstaller", return_value=installer):
            redhat_newt.run_c_installer(session)
        for method in (
            installer.boot_and_select_installation_options,
            installer.partition_storage,
            installer.select_components,
            installer.begin_package_installation,
            installer.configure_mouse,
            installer.configure_x11,
            installer.configure_network,
            installer.configure_installed_system,
            installer.configure_bootloader,
            installer.complete_installation,
        ):
            method.assert_called_once_with()

    def test_c_installer_explicitly_selects_default_installation_options(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.s = SimpleNamespace(boot_command=unittest.mock.Mock())
        installer.prompts = SimpleNamespace(
            boot_prompt="boot:",
            boot_command="",
            boot_sleep=0,
        )
        installer.settings = SimpleNamespace(
            color_prompt=False,
            language_prompt=True,
            keyboard_early=False,
            pcmcia_prompt=False,
            cdrom_type_prompt=True,
        )
        installer.locale = SimpleNamespace(keymap="us")
        installer.dialog = unittest.mock.Mock()

        installer.boot_and_select_installation_options()

        self.assertEqual(
            installer.dialog.select_menu_item.call_args_list,
            [
                call("English"),
                call("Local CDROM"),
                call("IDE (ATAPI)"),
            ],
        )

    def test_c_installer_chooses_yes_to_configure_networking(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.settings = SimpleNamespace(
            network_setup="direct",
            tcp_ip_form="network-and-broadcast",
        )
        installer.network_config = SimpleNamespace(
            ip="192.0.2.2",
            netmask="255.255.255.0",
            network="192.0.2.0",
            broadcast="192.0.2.255",
            domain="example.test",
            hostname="retro",
            gateway="192.0.2.1",
            nameserver="192.0.2.1",
        )
        installer.dialog = unittest.mock.Mock()

        installer.configure_network()

        installer.dialog.wait_for_title.assert_any_call("Network Configuration")
        installer.dialog.advance.assert_any_call("Yes")
        installer.dialog.wait_for_title.assert_any_call("Configure TCP/IP")
        self.assertEqual(
            installer.dialog.set_fields.call_args_list,
            [
                call(
                    {
                        "IP address:": "192.0.2.2",
                        "Netmask:": "255.255.255.0",
                        "Network address:": "192.0.2.0",
                        "Broadcast address:": "192.0.2.255",
                    }
                ),
                call(
                    {
                        "Domain name:": "example.test",
                        "Host name:": "retro",
                        "Default gateway (IP):": "192.0.2.1",
                        "Primary nameserver (IP):": "192.0.2.1",
                        "Secondary nameserver (IP):": "",
                        "Tertiary nameserver (IP):": "",
                    }
                ),
            ],
        )

    def test_c_installer_applies_the_configured_component_set(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.settings = SimpleNamespace(components=["C Development", "X Development"])
        installer.dialog = unittest.mock.Mock()

        installer.select_components()

        installer.dialog.wait_for_title.assert_called_once_with("Components to Install")
        installer.dialog.set_checklist_items.assert_called_once_with(
            ["C Development", "X Development"]
        )
        installer.dialog.advance.assert_called_once_with()

    def test_select_root_partition_workflow_runs_scripted_fdisk_first(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.settings = SimpleNamespace(partitioning="select-root-partition")
        installer.dialog = unittest.mock.Mock()
        installer._create_partitions_with_fdisk = unittest.mock.Mock()
        installer._select_root_partition = unittest.mock.Mock()

        installer.partition_storage()

        installer.dialog.wait_for_title.assert_any_call("Disk Setup")
        installer.dialog.press_button.assert_called_once_with("fdisk")
        installer._create_partitions_with_fdisk.assert_called_once_with()
        installer.dialog.wait_for_title.assert_any_call("Partition Disks")
        installer.dialog.advance.assert_called_once_with("Done")
        installer._select_root_partition.assert_called_once_with()

    def test_current_disk_partitions_workflow_waits_after_mount_editor(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.disk = SimpleNamespace(root_partition="/dev/hda2")
        installer.dialog = unittest.mock.Mock()

        installer._edit_current_disk_partitions()

        installer.dialog.set_fields.assert_called_once_with({"Mount Point:": "/"})
        installer.dialog.press_button.assert_any_call("Ok")
        installer.dialog.wait_for_title.assert_any_call("Current Disk Partitions")
        installer.dialog.wait_for_title.assert_any_call("Active Swap Space")

    def test_probe_and_configure_mouse_workflow_uses_combined_form(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.settings = SimpleNamespace(mouse_setup="probe-and-configure-mouse")
        installer.dialog = unittest.mock.Mock()

        installer.configure_mouse()

        self.assertEqual(
            installer.dialog.wait_for_title.call_args_list,
            [call("Probing Result"), call("Configure Mouse")],
        )
        installer.dialog.select_menu_item.assert_called_once_with("PS/2 Mouse")
        installer.dialog.set_checkbox.assert_called_once_with("Emulate 3 Buttons?")
        self.assertEqual(installer.dialog.advance.call_args_list, [call(), call()])

    def test_probe_and_emulation_workflow_keeps_separate_question(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.settings = SimpleNamespace(mouse_setup="probe-and-emulation")
        installer.dialog = unittest.mock.Mock()

        installer.configure_mouse()

        self.assertEqual(
            installer.dialog.wait_for_title.call_args_list,
            [call("Probing Result"), call("Emulate Three Buttons")],
        )
        self.assertEqual(installer.dialog.advance.call_args_list, [call(), call("Yes")])

    def test_x11_workflows_share_common_configuration_screens(self) -> None:
        cases = {
            "choose-card": [
                "Choose A Card",
                "Monitor Setup",
                "Video Memory",
                "Clockchip Configuration",
                "Select Video Modes",
            ],
            "pci-probe": [
                "PCI Probe",
                "Monitor Setup",
                "Screen Configuration",
                "Video Memory",
                "Clockchip Configuration",
                "Select Video Modes",
            ],
        }
        for workflow, titles in cases.items():
            with self.subTest(workflow=workflow):
                installer = object.__new__(redhat_newt.CInstaller)
                installer.settings = SimpleNamespace(
                    x11_setup=workflow,
                    x_card_label="Cirrus Logic GD543x",
                    x_video_memory_label="2048",
                )
                installer.dialog = unittest.mock.Mock()

                installer.configure_x11()

                self.assertEqual(
                    installer.dialog.wait_for_title.call_args_list,
                    [call(title) for title in titles],
                )
                installer.dialog.select_menu_item.assert_any_call("Generic Monitor")
                installer.dialog.select_menu_item.assert_any_call("2048")
                installer.dialog.select_menu_item.assert_any_call(
                    "No Clockchip Setting (recommended)"
                )
                if workflow == "choose-card":
                    installer.dialog.select_menu_item.assert_any_call(
                        "Cirrus Logic GD543x",
                        label_width=49,
                    )
                else:
                    installer.dialog.advance.assert_any_call("Don't Probe")

    def test_redhat_51_accepts_probed_tulip_and_selects_static_networking(
        self,
    ) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.settings = SimpleNamespace(
            network_setup="probe-static",
            tcp_ip_form="gateway-and-nameserver",
        )
        installer.network_config = SimpleNamespace(
            ip="192.0.2.2",
            netmask="255.255.255.0",
            network="192.0.2.0",
            broadcast="192.0.2.255",
            domain="example.test",
            hostname="retro",
            gateway="192.0.2.1",
            nameserver="192.0.2.1",
        )
        installer.dialog = unittest.mock.Mock()

        installer.configure_network()

        installer.dialog.wait_for_title.assert_any_call("Probe")
        self.assertNotIn(
            call("Digital 21040 (Tulip)"),
            installer.dialog.select_menu_item.call_args_list,
        )
        self.assertIn(
            call("Static IP address"),
            installer.dialog.select_menu_item.call_args_list,
        )
        self.assertEqual(
            installer.dialog.set_fields.call_args_list,
            [
                call(
                    {
                        "IP address:": "192.0.2.2",
                        "Netmask:": "255.255.255.0",
                        "Default gateway (IP):": "192.0.2.1",
                        "Primary nameserver:": "192.0.2.1",
                    }
                ),
                call(
                    {
                        "Domain name:": "example.test",
                        "Host name:": "retro",
                        "Secondary nameserver (IP):": "",
                        "Tertiary nameserver (IP):": "",
                    }
                ),
            ],
        )

    def test_c_installer_advances_configuration_dialogs_without_button_labels(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.settings = SimpleNamespace(
            timezone_prompt="Configure Timezones",
            timezone_clock_control="radio",
            keyboard_late=True,
            services_prompt=False,
            printer_prompt=None,
            password_field="Password        :",
            password="password",
            bootdisk_prompt=False,
        )
        installer.locale = SimpleNamespace(
            hardware_clock="utc",
            timezone="Etc/UTC",
            keymap="us",
        )
        installer.dialog = unittest.mock.Mock()

        installer.configure_installed_system()

        self.assertEqual(
            installer.dialog.wait_for_title.call_args_list,
            [
                call("Configure Timezones"),
                call("Configure Keyboard"),
                call("Root Password"),
            ],
        )
        installer.dialog.set_radio.assert_called_once_with("Universal time (GMT)")
        self.assertEqual(
            installer.dialog.select_menu_item.call_args_list,
            [call("Etc/UTC"), call("us")],
        )
        installer.dialog.set_fields.assert_called_once_with(
            {
                "Password        :": "password",
                "Password (again):": "password",
            },
            sensitive=True,
        )
        self.assertEqual(
            installer.dialog.advance.call_args_list,
            [call(), call(), call()],
        )

    def test_later_redhat_timeconfig_uses_gmt_checkbox_and_ok(self) -> None:
        for clock, checked in (("utc", True), ("local", False)):
            with self.subTest(clock=clock):
                installer = object.__new__(redhat_newt.CInstaller)
                installer.settings = SimpleNamespace(
                    timezone_prompt="Configure Timezones",
                    timezone_clock_control="checkbox",
                    keyboard_late=False,
                    services_prompt=True,
                    printer_prompt="Configure Printer",
                    password_field="Password        :",
                    password="password",
                    bootdisk_prompt=False,
                )
                installer.locale = SimpleNamespace(
                    hardware_clock=clock,
                    timezone="Etc/UTC",
                    keymap="us",
                )
                installer.dialog = unittest.mock.Mock()

                installer.configure_installed_system()

                installer.dialog.set_checkbox.assert_called_once_with(
                    "Hardware clock set to GMT", checked
                )
                installer.dialog.set_radio.assert_not_called()
                installer.dialog.select_menu_item.assert_called_once_with("Etc/UTC")
                self.assertEqual(
                    installer.dialog.advance.call_args_list,
                    [call(), call(), call()],
                )

    def test_complete_installation_waits_for_the_source_defined_done_dialog(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.settings = SimpleNamespace(password="password")
        installer.network_config = SimpleNamespace(hostname="retro")
        installer.dialog = unittest.mock.Mock()
        installer.s = unittest.mock.Mock()

        installer.complete_installation()

        installer.dialog.wait_for_title.assert_called_once_with("Done")
        installer.dialog.advance.assert_called_once_with()
        installer.s.set_boot.assert_called_once_with("c")

    def test_lilo_clears_the_staged_fat_disks_boot_label(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.disk = SimpleNamespace(
            target_disk="/dev/hda",
            fat_partition="/dev/hdb1",
        )
        installer.dialog = unittest.mock.Mock()
        installer.settings = SimpleNamespace(
            lilo_setup_dialogs=1,
            lilo_boot_labels=True,
            boot_label_field="Boot label :",
        )

        installer.configure_bootloader()

        installer.dialog.select_menu_item.assert_called_once_with("/dev/hda Master Boot Record")
        installer.dialog.select_partition.assert_called_once_with("/dev/hdb1")
        installer.dialog.set_fields.assert_called_once_with({"Boot label :": ""})
        self.assertEqual(
            installer.dialog.wait_for_title.call_args_list,
            [
                call("Lilo Installation"),
                call("Bootable Partitions"),
                call("Edit Boot Label"),
                call("Bootable Partitions"),
            ],
        )
        self.assertEqual(
            installer.dialog.press_button.call_args_list,
            [call("Edit"), call("Ok")],
        )
        self.assertEqual(installer.dialog.advance.call_args_list, [call(), call()])

    def test_partition_disks_workflow_waits_after_mount_editor(self) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.disk = SimpleNamespace(
            root_partition="/dev/hda2",
            fat_partition="/dev/hdb1",
            fat_mount="/retro",
        )
        installer.dialog = unittest.mock.Mock()
        installer._create_partitions_with_fdisk = unittest.mock.Mock()

        installer._partition_disks()

        installer.dialog.set_fields.assert_called_once_with({"Mount point :": "/retro"})
        installer.dialog.press_button.assert_any_call("Ok")
        installer.dialog.wait_for_title.assert_any_call("Partition Disks")
        installer.dialog.wait_for_title.assert_any_call("Active Swap Space")
        installer.dialog.wait_for_title.assert_any_call("Partition Disk")
        installer.dialog.advance.assert_any_call("Done")

    def test_redhat_41_lilo_has_two_setup_dialogs_then_boot_label_editor(
        self,
    ) -> None:
        installer = object.__new__(redhat_newt.CInstaller)
        installer.disk = SimpleNamespace(
            target_disk="/dev/hda",
            fat_partition="/dev/hdb1",
        )
        installer.dialog = unittest.mock.Mock()
        installer.settings = SimpleNamespace(
            lilo_setup_dialogs=2,
            lilo_boot_labels=True,
            boot_label_field="Boot label :",
        )

        installer.configure_bootloader()

        self.assertEqual(
            installer.dialog.wait_for_title.call_args_list,
            [
                call("Lilo Installation"),
                call("Lilo Installation"),
                call("Bootable Partitions"),
                call("Edit Boot Label"),
                call("Bootable Partitions"),
            ],
        )
        installer.dialog.select_menu_item.assert_called_once_with("/dev/hda Master Boot Record")
        installer.dialog.select_partition.assert_called_once_with("/dev/hdb1")

    def test_early_redhat_flow_composes_release_specific_phases(self) -> None:
        session = SimpleNamespace(
            config=RetroConfig(
                context=SimpleNamespace(),
                data={
                    "install": {
                        "driver": "redhat-perl",
                        "redhat": {"flow": "1.1", "package_series": []},
                    }
                },
            )
        )
        installer = unittest.mock.Mock()
        installer.settings.flow = "1.1"
        with patch.object(redhat_dialog, "PerlInstaller", return_value=installer):
            redhat_dialog.run_perl_installer(session)
        installer.boot.assert_called_once_with()
        installer.load_ramdisk.assert_called_once_with("rootdisk.img")
        installer.prepare_dialog.assert_called_once_with(
            "Welcome to the Red Hat Commercial Linux installation program!"
        )
        installer.insert_boot_disk.assert_called_once_with()
        installer.reset_mock()
        installer.settings.flow = "3.0.3"
        with patch.object(redhat_dialog, "PerlInstaller", return_value=installer):
            redhat_dialog.run_perl_installer(session)
        installer.install.assert_called_once_with(
            "This script will walk you through each step of the installation.",
            x_vga=True,
        )

    def test_early_redhat_x_configuration_uses_detected_cirrus_path(self) -> None:
        installer = object.__new__(redhat_dialog.PerlInstaller)
        installer.dialog = unittest.mock.Mock()

        installer._configure_x()

        choices = installer.dialog.answer_until.call_args.args
        self.assertEqual([choice.answer for choice in choices[:4]], ["yes"] * 4)
        self.assertEqual(choices[0].text, "Do you want to autoprobe?")
        self.assertIn("Your chipset appears to be:", choices[1].text)
        self.assertIn("2048 Kb of memory", choices[2].text)
        self.assertIn("following clocks", choices[3].text)
        self.assertEqual(choices[4].title, "Monitor Specs")
        self.assertEqual(choices[4].answer, "Generic Monitor")
        self.assertEqual(choices[5].widget, "checklist")
        self.assertEqual(choices[6].answer, "640x480   60Hz      Non-Interlaced")
        self.assertEqual(choices[7].answer, "no")
        self.assertEqual(choices[8].answer, "")
        self.assertEqual(choices[9].answer, "Two")

    def test_early_redhat_uses_configured_boot_prompt(self) -> None:
        installer = object.__new__(redhat_dialog.PerlInstaller)
        installer.s = unittest.mock.Mock()
        installer.prompts = SimpleNamespace(
            boot_prompt="custom boot:",
            boot_command="linux expert",
        )

        installer.boot()

        installer.s.boot_command.assert_called_once_with("custom boot:", "linux expert")

    def test_early_redhat_finish_uses_locale_and_root_password(self) -> None:
        installer = object.__new__(redhat_dialog.PerlInstaller)
        installer.s = unittest.mock.Mock()
        installer.dialog = unittest.mock.Mock()
        installer.disk = SimpleNamespace(target_disk="/dev/hda")
        installer.network = SimpleNamespace(hostname="redhat", domain="retro.net")
        installer.locale = SimpleNamespace(
            hardware_clock="local",
            timezone="US/Central",
            keymap="us.map",
        )
        installer.settings = SimpleNamespace(root_password="secret")
        installer._configure_x_vga = unittest.mock.Mock()
        installer._configure_user = unittest.mock.Mock()
        installer._set_root_password = unittest.mock.Mock()

        installer._finish(x_vga=True)

        choices = installer.dialog.answer_until.call_args.args
        answers = {choice.title: choice.answer for choice in choices}
        self.assertEqual(answers["Clock Configuration"], "Local Time")
        self.assertEqual(answers["Time Zone"], "US/Central")
        self.assertEqual(answers["Keyboard Configuration"], "us.map")
        installer.s.run_postinst.assert_called_once_with(
            "secret",
            login="redhat.retro.net login:",
            shell="[root@redhat /root]#",
        )

    def test_early_redhat_configures_optional_user(self) -> None:
        installer = object.__new__(redhat_dialog.PerlInstaller)
        installer.dialog = unittest.mock.Mock()
        installer.settings = SimpleNamespace(user=None, user_home=True)

        installer._configure_user()

        choice = installer.dialog.answer.call_args.args[0]
        self.assertEqual((choice.title, choice.answer), ("Create User", "no"))

        installer.dialog.reset_mock()
        installer.settings.user = "retro"
        installer.settings.user_home = False
        installer._configure_user()

        choices = [call.args[0] for call in installer.dialog.answer.call_args_list]
        self.assertEqual(
            [(choice.title, choice.answer) for choice in choices],
            [
                ("Create User", "yes"),
                ("User Name", "retro"),
                ("Home Directory", "no"),
                ("Create User", "no"),
            ],
        )
        self.assertEqual(
            choices[-1].text,
            "Do you want to create another user account?",
        )

    def test_early_redhat_sets_root_password_for_both_prompt_styles(self) -> None:
        installer = object.__new__(redhat_dialog.PerlInstaller)
        installer.s = unittest.mock.Mock()
        installer.settings = SimpleNamespace(root_password="secret")

        installer._set_root_password()

        self.assertEqual(
            installer.s.vga_wait.call_args_list,
            [
                call(
                    r"(New password \(\? for help\):|Enter new password:)",
                    match=Match.REGEX,
                ),
                call(
                    r"(New password \(again\):|Re-type new password:)",
                    match=Match.REGEX,
                ),
            ],
        )
        self.assertEqual(
            installer.s.kb_type.call_args_list,
            [call("secret\n"), call("secret\n")],
        )

        installer.s.reset_mock()
        installer.settings.root_password = ""
        installer._set_root_password()
        self.assertEqual(
            installer.s.kb_type.call_args_list,
            [call("\n")],
        )
        installer.s.vga_wait.assert_called_once_with(
            r"(New password \(\? for help\):|Enter new password:)",
            match=Match.REGEX,
        )

    def test_early_redhat_quotes_dialog_media_paths(self) -> None:
        installer = object.__new__(redhat_dialog.PerlInstaller)
        installer.s = unittest.mock.Mock()
        installer.disk = SimpleNamespace(
            fat_mount="/media/retro disk",
            fat_filesystem="msdos",
            fat_partition="/dev/disk 1",
            target_disk="/dev/hda",
            swap_mb=64,
        )

        with patch.object(redhat_dialog, "Fdisk"):
            installer.prepare_dialog("first dialog")

        installer.s.serial_shell_send.assert_any_call(
            "mkdir -p '/media/retro disk' && " "mount -t msdos '/dev/disk 1' '/media/retro disk'"
        )
        installer.s.serial_shell_send.assert_any_call(
            "cp '/media/retro disk/guestlib.d/dialog.sh' /usr/bin/dialog"
        )

    def test_redhat_303_x_configuration_uses_installed_dialog_on_vga(self) -> None:
        installer = object.__new__(redhat_dialog.PerlInstaller)
        installer.s = unittest.mock.Mock()

        installer._configure_x_vga()

        prompts = [call.args[0] for call in installer.s.vga_wait.call_args_list]
        self.assertEqual(
            prompts,
            [
                "Do you want to autoprobe?",
                "Your chipset appears to be:",
                "Kb of memory.",
                "Your card appears to have the following clocks:",
                "Please choose a monitor.",
                "Select the modes you wish to include in XF86Config.",
                "Choose primary video mode.",
                "Do you have such a card?",
                "There are a large number of configuration options",
                "How many buttons are on your mouse?",
            ],
        )
        self.assertEqual(
            installer.s.kb_press.call_args_list[4].args,
            ("g", "g", "ret"),
        )


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
    def test_answer_requires_keyword_arguments(self) -> None:
        with self.assertRaises(TypeError):
            Answer("menu", "Main", "Next")  # type: ignore[call-arg]

        answer = Answer(widget="menu", title="Main", text="Prompt", answer="Next")

        self.assertEqual(answer.answer, "Next")

    def test_callback_rewinds_the_screen_for_nested_handler(self) -> None:
        serial = _DialogSerial("TITLE: Main\nTYPE: menu\nITEM: Next :: Install\nRESPONSE:\n")
        dialog = Dialog(serial)

        def handler(_: str) -> None:
            dialog.answer(AnswerTitle("menu", "Main", "Next"))

        dialog.answer(AnswerTitle("menu", "Main", handler, item="Next :: Install"))
        self.assertEqual(serial.answers, ["Next"])

    def test_checklist_selections_resolve_decorated_item_tags(self) -> None:
        screen = (
            "TITLE: Select Series\n"
            "TYPE: checklist\n"
            "ITEM:   15.0 MB - Applications :: ON\n"
            "ITEM:   46.3 MB - X Windows :: ON\n"
            "RESPONSE:\n"
        )
        serial = _DialogSerial(screen)

        Dialog(serial).answer(
            AnswerTitle(
                "checklist",
                "Select Series",
                ("Applications", "X Windows"),
            )
        )

        self.assertEqual(
            serial.answers,
            ['"  15.0 MB - Applications" "  46.3 MB - X Windows"'],
        )

    def test_empty_checklist_selection_does_not_accept_defaults(self) -> None:
        serial = _DialogSerial(
            "TITLE: Select Series\n" "TYPE: checklist\n" "ITEM: Applications :: ON\n" "RESPONSE:\n"
        )

        Dialog(serial).answer(AnswerTitle("checklist", "Select Series", ()))

        self.assertEqual(serial.answers, ['""'])

    def test_unknown_checklist_selection_fails_with_context(self) -> None:
        serial = _DialogSerial(
            "TITLE: Select Series\n" "TYPE: checklist\n" "ITEM: Applications :: ON\n" "RESPONSE:\n"
        )

        with self.assertRaisesRegex(
            RuntimeError,
            "Checklist selection 'Typo' matched 0 items in 'Select Series'",
        ):
            Dialog(serial).answer(AnswerTitle("checklist", "Select Series", ("Typo",)))

    def test_pkgtool_callback_consumes_rewound_trigger_screen(self) -> None:
        def screen(title: str, widget: str) -> str:
            return f"TITLE: {title}\nTYPE: {widget}\nRESPONSE:\n"

        serial = _DialogSerial(
            screen("CONFIGURE NETWORK?", "yesno")
            + screen("NETWORK SETUP COMPLETE", "msgbox")
            + screen("SETUP COMPLETE", "msgbox")
        )
        dialog = Dialog(serial)
        Pkgtool(SimpleNamespace(dialog=dialog), pkgtool_config())._configure()
        self.assertEqual(serial.answers, ["yes", "ok", "ok"])

    def test_none_answer_leaves_lookahead_for_outer_dispatch(self) -> None:
        def screen(item: str) -> str:
            return "TITLE: Main\nTYPE: menu\n" f"ITEM: Next :: {item}\nRESPONSE:\n"

        serial = _DialogSerial(screen("Install Base") + screen("Install Kernel"))
        dialog = Dialog(serial)

        def install_base(_: str) -> None:
            dialog.answer(AnswerTitle("menu", "Main", "Next", item="Install Base"))
            dialog.answer(AnswerTitle("menu", "Main", None, exit=True))

        dialog.answer_until(
            AnswerTitle("menu", "Main", install_base, item="Install Base"),
            AnswerTitle("menu", "Main", "Next", item="Install Kernel", exit=True),
        )
        self.assertEqual(serial.answers, ["Next", "Next"])

    def test_answer_can_match_inputbox_prompt_text(self) -> None:
        serial = _DialogSerial(
            "TITLE: Network Configuration\n"
            "TYPE: inputbox\n"
            "TEXT: What hostname have you selected?\n"
            "RESPONSE:\n"
        )
        dialog = Dialog(serial)

        dialog.answer(AnswerText("inputbox", "Network Configuration", "What hostname", "retro"))

        self.assertEqual(serial.answers, ["retro"])

    def test_literal_titles_are_case_insensitive(self) -> None:
        serial = _DialogSerial("TITLE: X configuration\nTYPE: menu\nRESPONSE:\n")
        dialog = Dialog(serial)

        dialog.answer(AnswerTitle("menu", "X Configuration", ""))

        self.assertEqual(serial.answers, [""])


class DinstallTests(unittest.TestCase):
    def test_start_matches_the_title_inside_its_cp437_dialog_border(self) -> None:
        session = SimpleNamespace(
            dialog=unittest.mock.Mock(),
            vga_wait=unittest.mock.Mock(),
            kb_press=unittest.mock.Mock(),
            kb_type=unittest.mock.Mock(),
            serial_shell_start=unittest.mock.Mock(),
            serial_shell_send=unittest.mock.Mock(),
            serial_shell_exit=unittest.mock.Mock(),
            serial=unittest.mock.Mock(),
        )

        with patch("hostlib.installers.debian.Fdisk"):
            Dinstall(session, dinstall_config())._start()

        self.assertEqual(
            session.vga_wait.call_args_list[0],
            call("Select Color or Monochrome"),
        )

    def test_filesystem_module_is_selected_from_its_menu(self) -> None:
        """Filesystem modules use the same Dinstall module workflow as network drivers."""
        dialog = unittest.mock.Mock()
        session = SimpleNamespace(
            dialog=dialog,
            vga_wait=unittest.mock.Mock(),
            kb_press=unittest.mock.Mock(),
        )
        driver = Dinstall(session, dinstall_config(debian={"fs_module": "vfat"}))

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
            dinstall_config(
                disk={"fat_mount": "/media/retro"},
                debian={"kernel_floppy": None},
            ),
        )

        driver._base("")
        base_choices = dialog.answer_until.call_args.args
        self.assertEqual(base_choices[1].answer, "/media/retro")
        self.assertEqual(base_choices[3].answer, "/media/retro")

        driver._kernel("")
        kernel_choices = dialog.answer_until.call_args.args
        self.assertEqual(kernel_choices[3].answer, "/media/retro")
        self.assertEqual(kernel_choices[5].answer, "/media/retro")

    def test_base_configuration_navigates_timezone_path_and_sets_clock_mode(self) -> None:
        root = Path(__file__).resolve().parent.parent
        debian_11 = load_config(Context.create(root, "install", "debian/1.1/official")).install
        for config, answers in (
            (debian_11, ["Etc\n", "UTC\n", "y\n"]),
            (
                dinstall_config(
                    locale={"timezone": "US/Central", "hardware_clock": "local"},
                    debian={"configure_keyboard": True},
                ),
                ["US\n", "Central\n", "n\n"],
            ),
        ):
            with self.subTest(timezone=config.locale.timezone):
                session = SimpleNamespace(
                    dialog=unittest.mock.Mock(),
                    serial=unittest.mock.Mock(),
                    vga_wait=unittest.mock.Mock(),
                    kb_type=unittest.mock.Mock(),
                )
                driver = Dinstall(session, config)

                driver._configure_base("")

                self.assertEqual(
                    session.vga_wait.call_args_list,
                    [
                        call("Which?", match=Match.LINE),
                        call("Which?", match=Match.LINE),
                        call(
                            r"Is your system clock set to GMT( \(y/n\) \[y\])?[?]",
                            match=Match.REGEX,
                        ),
                    ],
                )
                self.assertEqual(
                    session.kb_type.call_args_list,
                    [call(answer) for answer in answers],
                )
                session.serial.prompt.assert_called_once_with("RESPONSE:", answer="yes")

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

        Dinstall(session, dinstall_config())._postinst()

        session.serial_shell_start.assert_called_once()
        session.serial_shell_send.assert_called_once_with(session.postinst_command, wait=False)
        serial.answer_any.assert_called_once_with([("Configure package?", "yes", False)])
        serial.wait.assert_called_once_with("Configuration complete!", line=True)
        session.serial_shell_exit.assert_called_once()

        session.config.postinst = PostinstConfig(stages=["packages", "tty"], packages=packages)
        session.serial_shell_exit.reset_mock()
        Dinstall(session, dinstall_config())._postinst()
        session.serial_shell_exit.assert_not_called()


class PkgtoolPromptTests(unittest.TestCase):
    def test_prepare_accepts_a_decorated_root_shell_prompt(self) -> None:
        session = SimpleNamespace(
            dialog=unittest.mock.Mock(),
            serial_shell_start=unittest.mock.Mock(),
            serial_shell_send=unittest.mock.Mock(),
            serial_shell_exit=unittest.mock.Mock(),
            kb_type=unittest.mock.Mock(),
        )

        with patch("hostlib.installers.slackware.Fdisk"):
            Pkgtool(session, pkgtool_config())._prepare()

        shell_prompt = r"# *$"
        session.serial_shell_start.assert_called_once_with(
            screen_prompt=shell_prompt, screen_match=Match.REGEX
        )
        session.serial_shell_exit.assert_called_once_with(
            screen_prompt=shell_prompt, screen_match=Match.REGEX
        )

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
                config=pkgtool_config(),
            )

        session.vga_wait.assert_called_once_with("insert root disk", match=Match.LINE)
        session.kb_type.assert_not_called()

    def test_boot_answers_a_second_vfs_prompt_after_changing_root_disk(self) -> None:
        session = SimpleNamespace(
            boot_command=unittest.mock.Mock(),
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
                config=pkgtool_config(),
            )

        session.change_floppy.assert_called_once_with("root.img")
        self.assertEqual(
            session.kb_press.call_args_list,
            [unittest.mock.call("ret"), unittest.mock.call("ret")],
        )
        session.vga_wait.assert_any_call("VFS: Insert root floppy and press ENTER")


class SysinstallTests(unittest.TestCase):
    def test_bootdisk_prompt_creates_a_1440k_floppy(self) -> None:
        with temporary_root() as root:
            serial = SimpleNamespace(
                wait_any=unittest.mock.Mock(side_effect=[(1, ""), (2, "")]),
                send=unittest.mock.Mock(),
            )
            session = SimpleNamespace(
                qemu_dir=root,
                serial=serial,
                change_floppy=unittest.mock.Mock(),
            )
            Sysinstall(session, sysinstall_config())._packages()

            image = root / "bootdisk.img"
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
                    _ = config.extraction
                    validated.append(path)
        self.assertEqual(len(validated), 50)

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
                "slackware/1.01/channel1",
                "slackware/1.01/official+sls",
                "slackware/1.0beta/official",
                "slackware/3.6/linuxmall",
                "debian/1.1/official",
                "debian/1.1/infomagic",
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
            default_action = install.get("default_action")
            for step in install["steps"]:
                self.assertIn(
                    step.get("action", default_action), STEP_HANDLERS, path.relative_to(root)
                )

    def test_debian_091_uses_vga_prompt_questions(self) -> None:
        root = Path(__file__).resolve().parent.parent
        path = root / "debian/0.91/infomagic/config.toml"
        install = tomllib.loads(path.read_text())["install"]
        prompts = [
            step
            for step in install["steps"]
            if step.get("action", install.get("default_action")) == "prompt"
        ]
        lilo_steps = [
            step
            for step in install["steps"]
            if step.get("action") == "serial-shell-send" and isinstance(step["command"], list)
        ]
        self.assertEqual(install["default_transport"], "vga")
        self.assertEqual(install["default_action"], "prompt")
        self.assertTrue(all("questions" in step and "text" not in step for step in prompts))
        self.assertTrue(any(len(step["questions"]) > 1 for step in prompts))
        self.assertEqual(len(lilo_steps), 1)
        self.assertFalse((root / "guestlib/deb091/lilo.sh").exists())
        self.assertFalse((root / "guestlib/deb091/pkginst.sh").exists())
        self.assertIn(
            'find "$INSTALL_D/packages" -iname',
            (root / "debian/0.91/infomagic/postinst.sh").read_text(),
        )
        syntax = subprocess.run(
            ["sh", "-n"],
            input="\n".join(lilo_steps[0]["command"]).replace(
                "${install.disk.linux_partition}", "hda2"
            ),
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(syntax.returncode, 0, syntax.stderr)

    def test_canonical_media_link_preserves_already_named_image(self) -> None:
        with temporary_root() as root:
            boot = root / "boot.img"
            boot.write_bytes(b"boot image")
            MediaStager._link("boot.img", boot)
            self.assertFalse(boot.is_symlink())
            self.assertEqual(boot.read_bytes(), b"boot image")

    def test_canonical_media_link_rejects_a_missing_source(self) -> None:
        with temporary_root() as root:
            destination = root / "boot.img"
            with self.assertRaisesRegex(ConfigError, "Link source not found: missing.img"):
                MediaStager._link("missing.img", destination)


class VgaTests(unittest.IsolatedAsyncioTestCase):
    @staticmethod
    def _vga_cells(cells):
        return b"".join(
            character.encode("cp437") + bytes((attribute,)) for character, attribute in cells
        )

    def test_snapshot_rejects_invalid_geometry(self) -> None:
        with self.assertRaisesRegex(ValueError, "columns"):
            ScreenSnapshot.capture(b"A\x07", columns=0)
        with self.assertRaisesRegex(ValueError, "rows"):
            ScreenSnapshot.capture(b"A\x07", rows=0)
        with self.assertRaisesRegex(ValueError, "character/attribute pairs"):
            ScreenSnapshot.capture(b"A")

    def test_snapshot_decodes_character_attribute_pairs(self) -> None:
        snapshot = ScreenSnapshot.capture(b"A\x07B\x07\x00\x07C\x07", 2, 2)
        self.assertEqual(snapshot.text, "AB\n C")

    def test_snapshot_pads_a_partial_final_row(self) -> None:
        snapshot = ScreenSnapshot.capture(b"A\x07B\x07C\x07", columns=2, rows=None)

        self.assertEqual(snapshot.text, "AB\nC ")
        self.assertEqual(snapshot.cell(2, 2).character, " ")

    def test_decode_converts_cp437_graphics_before_removing_controls(self) -> None:
        memory = b"\xda\x07\xc4\x07\xbf\x07\x1b\x07"
        self.assertEqual(ScreenSnapshot.capture(memory, 4, 1).text, "┌─┐ ")

    def test_full_memory_decode_finds_scrolled_console_text(self) -> None:
        memory = b" " + b"\x07"
        memory *= 80 * 25
        memory += b"V\x07F\x07S\x07:\x07"
        self.assertNotIn("VFS:", ScreenSnapshot.capture(memory, 80, 25).text)
        self.assertIn("VFS:", ScreenSnapshot.capture(memory, 80, None).text)

    async def test_observer_polls_only_while_waiting(self) -> None:
        monitor = AsyncMock()
        with temporary_root() as root:
            observer = ScreenObserver(monitor, root, interval=0.001)
            frames = [SimpleNamespace(text=value) for value in ("boot:", "boot:", "login:")]
            observer.capture = AsyncMock(side_effect=frames)
            screen = await observer.wait(lambda value: "login:" in value, 1)
        self.assertEqual(screen, "login:")
        self.assertEqual(observer.capture.await_count, 3)

    async def test_wait_ignores_pre_return_screen_before_starting_timeout(self) -> None:
        monitor = AsyncMock()
        with temporary_root() as root:
            observer = ScreenObserver(monitor, root, interval=0.01)
            observer._current = "Full Name []:"
            observer.invalidate()
            frames = [
                SimpleNamespace(text=value)
                for value in ("Full Name []:", "Is the information correct? [y/n]")
            ]
            observer.capture = AsyncMock(side_effect=frames)
            screen = await observer.wait(
                lambda value: "information correct" in value,
                timeout=0.001,
            )
        self.assertIn("information correct", screen)

    async def test_snapshot_wait_returns_an_initial_match_without_sleeping(self) -> None:
        snapshot = ScreenSnapshot.capture(b"O\x74k\x74", columns=2, rows=1)
        monitor = AsyncMock()
        with temporary_root() as root:
            observer = ScreenObserver(monitor, root)
            observer.capture = AsyncMock(return_value=snapshot)
            with patch("hostlib.vga.asyncio.sleep", new_callable=AsyncMock) as sleep:
                matched = await observer.wait_snapshot(
                    lambda frame: frame.text == "Ok",
                    timeout=1,
                    rows=1,
                    interval=0.05,
                )

        self.assertEqual(matched, snapshot)
        observer.capture.assert_awaited_once_with(1)
        sleep.assert_not_awaited()

    def test_snapshot_cell_enforces_one_based_bounds(self) -> None:
        snapshot = ScreenSnapshot.capture(b"A\x07B\x07", columns=2, rows=1)

        self.assertEqual(snapshot.cell(1, 2).character, "B")
        for row, column in ((0, 1), (1, 0), (2, 1), (1, 3)):
            with self.subTest(row=row, column=column):
                with self.assertRaisesRegex(ValueError, "outside this snapshot"):
                    snapshot.cell(row, column)

    def test_snapshot_view_preserves_absolute_coordinates(self) -> None:
        snapshot = ScreenSnapshot.capture(
            self._vga_cells((character, 0x07) for character in "ABCDEFGHIJKL"),
            columns=4,
            rows=3,
        )
        view = snapshot.view(ScreenBounds(2, 2, 3, 3))

        self.assertEqual(view.lines, ("FG", "JK"))
        self.assertEqual("".join(cell.character for cell in view.cells), "FGJK")
        self.assertEqual(view.cell(3, 2).character, "J")
        with self.assertRaisesRegex(ValueError, "outside this view"):
            view.cell(1, 2)

    async def test_bounded_capture_reads_only_requested_vga_rows(self) -> None:
        monitor = AsyncMock()
        with temporary_root() as root:

            async def save(command):
                _, _, byte_count, destination = command.split()
                (root / destination).write_bytes(b" \x07" * (int(byte_count) // 2))

            monitor.hmp.side_effect = save
            observer = ScreenObserver(monitor, root)
            snapshot = await observer.capture(rows=3)

        self.assertEqual(len(snapshot.contents), 3)
        command = monitor.hmp.await_args.args[0].split()
        self.assertEqual(command[2], "480")

    async def test_snapshot_wait_rejects_invalidated_matching_old_text(self) -> None:
        old = ScreenSnapshot.capture(b"O\x74k\x74 \x07", columns=3, rows=1)
        fresh = ScreenSnapshot.capture(b"O\x74k\x74!\x07", columns=3, rows=1)
        monitor = AsyncMock()
        with temporary_root() as root:
            observer = ScreenObserver(monitor, root, interval=0.001)
            observer._current = old.text
            observer.invalidate()
            observer.capture = AsyncMock(side_effect=[old, fresh])
            matched = await observer.wait_snapshot(
                lambda frame: frame.text.startswith("Ok"),
                timeout=1,
                rows=1,
                interval=0.001,
            )

        self.assertEqual(matched, fresh)
        self.assertEqual(observer.capture.await_count, 2)

    async def test_snapshot_wait_exponentially_backs_off_until_match(self) -> None:
        waiting = ScreenSnapshot.capture(b".\x07", columns=1, rows=1)
        matched = ScreenSnapshot.capture(b"!\x07", columns=1, rows=1)
        monitor = AsyncMock()
        with temporary_root() as root:
            observer = ScreenObserver(monitor, root, interval=0.25)
            observer.capture = AsyncMock(side_effect=[waiting, waiting, waiting, matched])
            with patch("hostlib.vga.asyncio.sleep", new_callable=AsyncMock) as sleep:
                result = await observer.wait_snapshot(
                    lambda frame: frame.text == "!",
                    timeout=1,
                    rows=1,
                )

        self.assertEqual(result, matched)
        self.assertEqual(
            [item.args[0] for item in sleep.await_args_list],
            [0.01, 0.02, 0.04],
        )


class NewtSession:
    """Provide the production snapshot-wait surface to synchronous dialog fakes."""

    def vga_wait_snapshot(self, predicate, *, rows=None, **_):
        snapshot = self.vga_screen(rows)
        predicate(snapshot)
        return snapshot


class NewtDialogTests(unittest.TestCase):
    @staticmethod
    def _snapshot(lines, attributes):
        width = max(map(len, lines))
        memory = b"".join(
            character.encode("cp437") + bytes((attributes.get((row, column), 0x70),))
            for row, line in enumerate(lines, 1)
            for column, character in enumerate(line.ljust(width), 1)
        )
        return ScreenSnapshot.capture(memory, columns=width, rows=len(lines))

    @classmethod
    def _menu(cls, active):
        lines = [
            "┌────┤ Choose A Card ├────┐",
            "│                         │",
            "│ Cirrus Logic GD542x     │",
            "│ Cirrus Logic GD543x     │",
            "│                         │",
            "└─────────────────────────┘",
        ]
        attributes = {(1, column): 0x74 for column in range(7, 20)}
        row = 3 if active == "GD542x" else 4
        for column in range(3, 27):
            attributes[(row, column)] = 0x1E
        return cls._snapshot(lines, attributes)

    def test_parses_title_bounds_and_active_menu_item(self) -> None:
        state = parse_dialog(self._menu("GD543x"))

        self.assertEqual(state.title, "Choose A Card")
        self.assertEqual(state.view.bounds, ScreenBounds(1, 1, 6, 27))
        self.assertEqual(state.active_item, "Cirrus Logic GD543x")

    @classmethod
    def _timezone(cls, focused, universal):
        lines = [
            "┌───┤ Configure Timezones ├────────┐",
            "│                                  │",
            "│ (*) Local time                   │",
            "│ ( ) Universal time (GMT)         │",
            "│                                  │",
            "│ UTC                              │",
            "│ US/Eastern                       │",
            "│                                  │",
            "└──────────────────────────────────┘",
        ]
        attributes = {(1, column): 0x74 for column in range(6, 25)}
        attributes.update({(3, column): 0x1E for column in range(3, 17)})
        attributes.update({(4, column): 0x1E for column in range(3, 28)})
        attributes.update({(6, column): 0x1E for column in range(3, 7)})
        if universal:
            lines[2] = "│ ( ) Local time                   │"
            lines[3] = "│ (*) Universal time (GMT)         │"
        if focused is not None:
            focus_row = 3 if focused == "Local time" else 4
            attributes[(focus_row, 4)] = 0x61
        return cls._snapshot(lines, attributes)

    def test_timezone_radio_does_not_hide_the_active_timezone_menu_item(self) -> None:
        state = parse_dialog(self._timezone("Local time", False))

        self.assertEqual(
            state.selected_radios,
            {"local time": True, "universal time (gmt)": False},
        )
        self.assertEqual(state.focused_radio, "Local time")
        self.assertEqual(state.active_item, "UTC")

    def test_standalone_checkbox_does_not_hide_active_timezone_menu_item(
        self,
    ) -> None:
        lines = [
            "┌───┤ Configure Timezones ├──────────┐",
            "│ Format machine time is stored in:  │",
            "│ [*] Hardware clock set to GMT      │",
            "│                                    │",
            "│ What timezone are you in:          │",
            "│ SystemV/YST9YDT                ▒   │",
            "│ Turkey                         ▒   │",
            "│ UTC                            #   │",
            "│ US/Alaska                      ▒   │",
            "│                                    │",
            "└────────────────────────────────────┘",
        ]
        attributes = {(1, column): 0x74 for column in range(6, 25)}
        attributes.update({(3, column): 0x1E for column in range(3, 34)})
        attributes.update({(8, column): 0x1E for column in range(3, 32)})
        state = parse_dialog(self._snapshot(lines, attributes))

        self.assertEqual(
            state.checked,
            {"hardware clock set to gmt": True},
        )
        self.assertEqual(state.active_item, "UTC")
        self.assertEqual(
            state.visible_items,
            ("SystemV/YST9YDT", "Turkey", "UTC", "US/Alaska"),
        )

    def test_select_radio_traverses_and_verifies_the_requested_value(self) -> None:
        class Session(NewtSession):
            def __init__(self):
                self.frames = iter(
                    [
                        NewtDialogTests._timezone("Local time", False),
                        NewtDialogTests._timezone("Local time", False),
                        NewtDialogTests._timezone("Universal time (GMT)", False),
                        NewtDialogTests._timezone("Universal time (GMT)", True),
                        NewtDialogTests._timezone(None, True),
                    ]
                )
                self.keys = []

            def vga_screen(self, rows=None):
                return next(self.frames)

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        NewtDialog(session).set_radio("Universal time (GMT)")
        self.assertEqual(session.keys, ["up", "down", "spc", "tab"])

    def test_menu_can_match_a_fixed_width_name_before_a_model_column(self) -> None:
        card = "Cirrus Logic GD543x"
        row = f"{card:<49}CL-GD5430/5434"
        width = len(row) + 4
        title_border = "┌──┤ Choose A Card ├"
        lines = [
            title_border + "─" * (width - len(title_border) - 1) + "┐",
            "│" + " " * (width - 2) + "│",
            f"│ {row} │",
            "│" + " " * (width - 2) + "│",
            "└" + "─" * (width - 2) + "┘",
        ]
        attributes = {(1, column): 0x74 for column in range(5, 18)}
        attributes.update({(3, column): 0x1E for column in range(3, width)})
        frame = self._snapshot(lines, attributes)

        class Session(NewtSession):
            keys = []

            def vga_screen(self, rows=None):
                return frame

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        state = parse_dialog(frame)
        self.assertEqual(state.active_item, row)
        session = Session()
        NewtDialog(session).select_menu_item(card, label_width=49)
        self.assertEqual(session.keys, [])

    @classmethod
    def _partition_menu(cls, active):
        lines = [
            "┌────┤ Current Disk Partitions ├──────────┐",
            "│ Mount Point   Device  Requested  Type   │",
            "│               hda1    70M        swap   │",
            "│               hda2    2961M      Linux  │",
            "│               hdb1    503M       DOS    │",
            "└─────────────────────────────────────────┘",
        ]
        attributes = {(1, column): 0x74 for column in range(7, 32)}
        active_row = {"hda1": 3, "hda2": 4, "hdb1": 5}[active]
        attributes.update(
            {(active_row, column): 0x1E for column in range(3, len(lines[active_row - 1]))}
        )
        return cls._snapshot(lines, attributes)

    def test_partition_matches_canonical_device_to_bare_5x_rendering(self) -> None:
        class Session(NewtSession):
            def __init__(self):
                self.frames = iter(
                    [
                        NewtDialogTests._partition_menu("hdb1"),
                        NewtDialogTests._partition_menu("hda1"),
                        NewtDialogTests._partition_menu("hda1"),
                        NewtDialogTests._partition_menu("hda2"),
                    ]
                )
                self.keys = []

            def vga_screen(self, rows=None):
                return next(self.frames)

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        NewtDialog(session).select_partition("/dev/hda2")
        self.assertEqual(session.keys, ["pgup", "pgup", "down"])

    def test_dialog_title_does_not_require_a_color(self) -> None:
        frame = self._menu("GD542x")
        cells = frame.view(ScreenBounds(1, 1, len(frame.contents), frame.columns)).cells
        redless = ScreenSnapshot.capture(
            b"".join(
                cell.character.encode("cp437")
                + bytes((0x70 if cell.row == 1 else cell.attribute,))
                for cell in cells
            ),
            columns=frame.columns,
            rows=len(frame.contents),
        )
        self.assertEqual(parse_dialog(redless).title, "Choose A Card")

    def test_title_wait_searches_beyond_the_first_vga_page(self) -> None:
        menu = self._menu("GD542x")
        blank = bytes((ord(" "), 0x70)) * menu.columns
        frame = ScreenSnapshot(menu.columns, (blank,) * 25 + menu.contents)

        class Session(NewtSession):
            rows = "unset"
            screen_rows = []

            def vga_wait_snapshot(self, predicate, *, timeout=None, rows=None, interval=None):
                self.rows = rows
                incomplete = ScreenSnapshot(frame.columns, frame.contents[:-1])
                if predicate(incomplete):
                    raise AssertionError("partial dialog unexpectedly matched")
                if not predicate(frame):
                    raise AssertionError("title predicate did not match the later VGA page")
                return frame

            def vga_screen(self, rows=None):
                self.screen_rows.append(rows)
                return (
                    frame if rows is None else ScreenSnapshot(frame.columns, frame.contents[:rows])
                )

        session = Session()
        dialog = NewtDialog(session)
        with self.assertLogs("hostlib.newt_dialog", level="INFO") as captured:
            state = dialog.wait_for_title("Choose A Card")
        dialog.capture()
        self.assertEqual(
            [record.getMessage() for record in captured.records],
            [
                "⏳ Choose A Card",
                "📸 Choose A Card:\n" + "\n".join(state.view.lines),
            ],
        )
        self.assertIsNone(session.rows)
        self.assertEqual(state.view.bounds.top, 26)
        self.assertEqual(session.screen_rows, [state.view.bounds.bottom])

    def test_nested_dialog_uses_innermost_border_and_matches_its_title(self) -> None:
        width, height = 46, 12
        cells = [[" " for _ in range(width)] for _ in range(height)]

        def box(top, left, bottom, right, title):
            cells[top][left], cells[top][right] = "┌", "┐"
            cells[bottom][left], cells[bottom][right] = "└", "┘"
            for column in range(left + 1, right):
                cells[top][column] = cells[bottom][column] = "─"
            for row in range(top + 1, bottom):
                cells[row][left] = cells[row][right] = "│"
            rendered = f"┤ {title} ├"
            cells[top][left + 3 : left + 3 + len(rendered)] = rendered

        box(0, 0, 11, 45, "Partition Disk")
        box(3, 6, 9, 38, "Edit Mount Point")
        frame = self._snapshot(["".join(row) for row in cells], {})

        self.assertEqual(parse_dialog(frame).title, "Edit Mount Point")
        outer = parse_dialog(frame, title="Partition Disk")
        self.assertEqual(outer.view.bounds, ScreenBounds(1, 1, 12, 46))

    def test_title_wait_rejects_parent_until_child_dialog_closes(self) -> None:
        def frame(child: bool) -> ScreenSnapshot:
            width, height = 40, 10
            cells = [[" " for _ in range(width)] for _ in range(height)]

            def box(top, left, bottom, right, title):
                cells[top][left], cells[top][right] = "┌", "┐"
                cells[bottom][left], cells[bottom][right] = "└", "┘"
                for column in range(left + 1, right):
                    cells[top][column] = cells[bottom][column] = "─"
                for row in range(top + 1, bottom):
                    cells[row][left] = cells[row][right] = "│"
                rendered = f"┤ {title} ├"
                cells[top][left + 3 : left + 3 + len(rendered)] = rendered

            box(0, 0, 9, 39, "Parent")
            if child:
                box(3, 6, 7, 32, "Child")
            return self._snapshot(["".join(row) for row in cells], {})

        overlaid = frame(True)
        closed = frame(False)

        class Session(NewtSession):
            def vga_wait_snapshot(self, predicate, **_):
                if predicate(overlaid):
                    raise AssertionError("parent matched while child was still visible")
                if not predicate(closed):
                    raise AssertionError("parent did not match after child closed")
                return closed

        with self.assertLogs("hostlib.newt_dialog", level="INFO") as captured:
            state = NewtDialog(Session()).wait_for_title("Parent")

        self.assertEqual(state.title, "Parent")
        self.assertFalse(any("Child" in record.getMessage() for record in captured.records))

    def test_title_traces_its_own_border_when_dialogs_share_a_row(self) -> None:
        frame = self._snapshot(
            [
                "┌─┤ One ├─┐  ┌──┤ Two ├──┐",
                "│         │  │           │",
                "└─────────┘  └───────────┘",
            ],
            {},
        )

        one = parse_dialog(frame, title="One")
        two = parse_dialog(frame, title="Two")

        self.assertEqual(one.view.bounds, ScreenBounds(1, 1, 3, 11))
        self.assertEqual(two.view.bounds, ScreenBounds(1, 14, 3, 26))

    @classmethod
    def _buttons(cls, selected):
        lines = [
            "┌────┤ Confirm ├──────────┐",
            "│                         │",
            "│    ┌────┐  ┌────────┐   │",
            "│    │ Ok │  │ Cancel │   │",
            "│    └────┘  └────────┘   │",
            "│                         │",
            "└─────────────────────────┘",
        ]
        attributes = {(1, column): 0x74 for column in range(7, 16)}
        for label in ("Ok", "Cancel"):
            start = lines[3].index(label) + 1
            attributes.update({(4, column): 0x47 for column in range(start, start + len(label))})
            if label == selected:
                attributes.update(
                    {(4, column): 0x74 for column in range(start, start + len(label))}
                )
        return cls._snapshot(lines, attributes)

    @classmethod
    def _entry(cls, value="", *, sensitive=False, other=None):
        width = 16
        rendered = "" if sensitive else value
        lines = [
            "┌────┤ Entry ├─────────────────────┐",
            "│                                  │",
            f"│ Value: {rendered:_<{width}}          │",
        ]
        if other is not None:
            lines.append(f"│ Other: {other:_<{width}}          │")
        lines.extend(
            [
                "│                                  │",
                "└──────────────────────────────────┘",
            ]
        )
        attributes = {(1, column): 0x74 for column in range(7, 14)}
        attributes.update({(3, column): 0x1E for column in range(10, 10 + width)})
        if other is not None:
            attributes.update({(4, column): 0x1E for column in range(10, 10 + width)})
        return cls._snapshot(lines, attributes)

    def test_named_button_cycles_focus_then_activates(self) -> None:
        class Session(NewtSession):
            def __init__(self):
                self.frames = iter(
                    [
                        NewtDialogTests._buttons("Ok"),
                        NewtDialogTests._buttons("Cancel"),
                    ]
                )
                self.keys = []

            def vga_screen(self, rows=None):
                return next(self.frames)

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        with self.assertLogs("hostlib.newt_dialog", level="INFO") as captured:
            NewtDialog(session).press_button("Cancel")
        self.assertEqual(session.keys, ["tab", "ret"])
        self.assertIn("👇 Press Cancel", captured.output[0])

    def test_source_authorized_advance_uses_f12_without_button_animation(self) -> None:
        frame = self._buttons("Ok")

        class Session(NewtSession):
            keys = []

            def vga_screen(self, rows=None):
                return frame

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        with self.assertLogs("hostlib.newt_dialog", level="INFO") as captured:
            NewtDialog(session).advance("Ok")
        self.assertEqual(session.keys, ["f12"])
        self.assertIn("👇 Press Ok", captured.output[0])

    def test_unlabeled_advance_logs_default_without_focusing_highlighted_button(self) -> None:
        frame = self._buttons("Cancel")

        class Session(NewtSession):
            keys = []

            def vga_screen(self, rows=None):
                return frame

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        with self.assertLogs("hostlib.newt_dialog", level="INFO") as captured:
            NewtDialog(session).advance()
        self.assertEqual(session.keys, ["f12"])
        self.assertIn("👇 Press Ok", captured.output[0])

    def test_labeled_advance_cycles_focus_then_uses_f12(self) -> None:
        class Session(NewtSession):
            def __init__(self):
                self.frames = iter(
                    [
                        NewtDialogTests._buttons("Ok"),
                        NewtDialogTests._buttons("Cancel"),
                    ]
                )
                self.keys = []

            def vga_screen(self, rows=None):
                return next(self.frames)

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        NewtDialog(session).advance("Cancel")
        self.assertEqual(session.keys, ["tab", "f12"])

    def test_monochrome_multi_button_advance_uses_named_default(self) -> None:
        frame = self._buttons(None)

        class Session(NewtSession):
            keys = []

            def vga_screen(self, rows=None):
                return frame

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        NewtDialog(session).advance("Ok")
        self.assertEqual(session.keys, ["f12"])

    def test_set_fields_tabs_between_entries_and_verifies_them_together(self) -> None:
        before = self._entry("old", other="old")
        after = self._entry("one", other="two")

        class Session(NewtSession):
            keys = []
            typed = []

            def vga_screen(self, rows=None):
                return before

            def vga_wait_snapshot(self, predicate, **_):
                if not predicate(after):
                    raise AssertionError("updated entry did not match")
                return after

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

            def kb_type_quiet(self, text):
                self.typed.append(text)

        session = Session()
        NewtDialog(session).set_fields({"Value:": "one", "Other:": "two"})
        self.assertEqual(
            session.keys,
            ["ctrl-a", "ctrl-k", "tab", "ctrl-a", "ctrl-k"],
        )
        self.assertEqual(session.typed, ["one", "two"])

    def test_set_fields_matches_the_redhat_51_mount_point_label(self) -> None:
        width = 72
        title = "┤ Edit Partition: /dev/hda2 ├"
        top = "┌" + "─" * 19 + title
        top += "─" * (width - len(top) - 1) + "┐"

        def frame(value: str) -> ScreenSnapshot:
            entry = f"{value:_<30}"
            field = f"│{'   Mount Point:       ' + entry:<{width - 2}}│"
            lines = [
                top,
                f"│{'':<{width - 2}}│",
                field,
                f"│{'':<{width - 2}}│",
                "└" + "─" * (width - 2) + "┘",
            ]
            start = field.index(entry) + 1
            attributes = {(3, column): 0x1E for column in range(start, start + 30)}
            return self._snapshot(lines, attributes)

        before = frame("")
        after = frame("/")

        class Session(NewtSession):
            keys = []
            typed = []

            def vga_screen(self, rows=None):
                return before

            def vga_wait_snapshot(self, predicate, **_):
                if not predicate(after):
                    raise AssertionError("updated mount point did not match")
                return after

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

            def kb_type_quiet(self, text):
                self.typed.append(text)

        session = Session()
        NewtDialog(session).set_fields({"Mount Point:": "/"})

        self.assertEqual(session.typed, ["/"])
        self.assertEqual(session.keys, ["ctrl-a", "ctrl-k"])

    def test_set_fields_validates_every_exact_label_before_typing(self) -> None:
        frame = self._entry(other="")

        class Session(NewtSession):
            keys = []
            typed = []

            def vga_screen(self, rows=None):
                return frame

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

            def kb_type_quiet(self, text):
                self.typed.append(text)

        session = Session()
        with self.assertRaisesRegex(RuntimeError, "entry labeled 'ther:'"):
            NewtDialog(session).set_fields({"Value:": "one", "ther:": "two"})

        self.assertEqual(session.keys, [])
        self.assertEqual(session.typed, [])

    def test_set_fields_rejects_a_value_rendered_in_the_wrong_entry(self) -> None:
        frame = self._entry(other="Value")

        class Session(NewtSession):
            keys = []
            typed = []

            def vga_screen(self, rows=None):
                return frame

            def vga_wait_snapshot(self, predicate, **_):
                if predicate(frame):
                    raise AssertionError("unchanged entry unexpectedly matched")
                raise TimeoutError

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

            def kb_type_quiet(self, text):
                self.typed.append(text)

        session = Session()
        with self.assertRaisesRegex(RuntimeError, "did not render.*'Value:'"):
            NewtDialog(session).set_fields({"Value:": "Value"})

        self.assertEqual(session.typed, ["Value"])
        self.assertEqual(session.keys, ["ctrl-a", "ctrl-k"])

    def test_sensitive_text_entry_is_redacted_from_semantic_log(self) -> None:
        before = self._entry()
        after = self._entry("secret", sensitive=True)

        class Session(NewtSession):
            keys = []
            typed = []

            def vga_screen(self, rows=None):
                return before

            def vga_wait_snapshot(self, predicate, **_):
                if not predicate(after):
                    raise AssertionError("masked entry did not match")
                return after

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

            def kb_type_quiet(self, text):
                self.typed.append(text)

        session = Session()
        with self.assertLogs("hostlib.newt_dialog", level="INFO") as captured:
            NewtDialog(session).set_fields({"Value:": "secret"}, sensitive=True)

        self.assertEqual(session.typed, ["secret"])
        self.assertEqual(session.keys, ["ctrl-a", "ctrl-k"])
        self.assertIn("✏️  Edit Value: <redacted>", captured.output[0])
        self.assertNotIn("secret", captured.output[0])

    def test_empty_text_entry_is_logged_as_blank(self) -> None:
        frame = self._entry()

        class Session(NewtSession):
            def vga_screen(self, rows=None):
                return frame

            def vga_wait_snapshot(self, predicate, **_):
                if not predicate(frame):
                    raise AssertionError("empty entry did not match")
                return frame

            def kb_press_quiet(self, *keys):
                pass

            def kb_type_quiet(self, text):
                pass

        with self.assertLogs("hostlib.newt_dialog", level="INFO") as captured:
            NewtDialog(Session()).set_fields({"Value:": ""})

        self.assertIn("✏️  Edit Value: <blank>", captured.output[0])

    def test_monochrome_advance_uses_verified_f12_shortcut(self) -> None:
        frame = self._snapshot(
            [
                "┌──┤ Screen Configuration ├────┐",
                "│                              │",
                "│      ┌─────────────┐         │",
                "│      │ Don't Probe │         │",
                "│      └─────────────┘         │",
                "│                              │",
                "└──────────────────────────────┘",
            ],
            {},
        )

        class Session(NewtSession):
            keys = []

            def vga_screen(self, rows=None):
                return frame

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        NewtDialog(session).advance("Don't Probe")
        self.assertEqual(session.keys, ["f12"])

    def test_menu_navigation_scans_from_the_observed_top(self) -> None:
        class Session(NewtSession):
            def __init__(self):
                self.frames = iter(
                    [
                        NewtDialogTests._menu("GD542x"),
                        NewtDialogTests._menu("GD543x"),
                    ]
                )
                self.keys = []

            def vga_screen(self, rows=None):
                return next(self.frames)

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        NewtDialog(session).select_menu_item("Cirrus Logic GD543x")
        self.assertEqual(session.keys, ["down"])

    def test_menu_navigation_waits_past_a_stale_post_key_frame(self) -> None:
        top = self._menu("GD542x")
        target = self._menu("GD543x")

        class Session(NewtSession):
            def __init__(self):
                self.current = top
                self.keys = []

            def vga_screen(self, rows=None):
                return self.current

            def vga_wait_snapshot(self, predicate, *, timeout=None, rows=None, interval=None):
                if self.keys[-1] == "pgup":
                    raise TimeoutError
                if predicate(self.current):
                    raise AssertionError("stale frame unexpectedly satisfied transition")
                self.current = target
                if not predicate(self.current):
                    raise AssertionError("changed frame did not satisfy transition")
                return self.current

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        NewtDialog(session).select_menu_item("Cirrus Logic GD543x")
        self.assertEqual(session.keys, ["down"])

    @classmethod
    def _scroll_menu(cls, items, active):
        lines = [
            "┌────┤ Configure Timezones ├─────┐",
            "│ explanatory text               │",
            "│                                │",
            *(f"│ {item:<24}▒      │" for item in items),
            "│                                │",
            "└────────────────────────────────┘",
        ]
        attributes = {(1, column): 0x74 for column in range(7, 26)}
        active_row = 4 + items.index(active)
        attributes.update(
            {(active_row, column): 0x1E for column in range(3, len(lines[active_row - 1]))}
        )
        return cls._snapshot(lines, attributes)

    def test_scrollbar_defines_visible_menu_rows(self) -> None:
        state = parse_dialog(self._scroll_menu(["Etc/Greenwich", "Etc/UCT", "Etc/UTC"], "Etc/UCT"))

        self.assertEqual(
            state.visible_items,
            ("Etc/Greenwich", "Etc/UCT", "Etc/UTC"),
        )

    def test_long_menu_scans_visible_pages_before_aligning_target(self) -> None:
        middle = self._scroll_menu(["M1", "M2", "M3"], "M2")
        top = self._scroll_menu(["A1", "A2", "A3"], "A1")
        middle_after_page = self._scroll_menu(["M1", "M2", "M3"], "M1")
        bottom = self._scroll_menu(["Z1", "Etc/UTC", "Z3"], "Z1")
        selected = self._scroll_menu(["Z1", "Etc/UTC", "Z3"], "Etc/UTC")

        class Session(NewtSession):
            def __init__(self):
                self.frames = iter([middle, top, top, middle_after_page, bottom, selected])
                self.keys = []

            def vga_screen(self, rows=None):
                return next(self.frames)

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        NewtDialog(session).select_menu_item("Etc/UTC")
        self.assertEqual(
            session.keys,
            ["pgup", "pgup", "pgdn", "pgdn", "down"],
        )

    @classmethod
    def _checklist(cls, active, checked):
        lines = [
            "┌────┤ Components to Install ├─────┐",
            "│                                  │",
            f"│ [{'*' if checked.get('One') else ' '}] One                          │",
            f"│ [{'*' if checked.get('Two') else ' '}] Two                          │",
            "│                                  │",
            "└──────────────────────────────────┘",
        ]
        attributes = {(1, column): 0x74 for column in range(7, 28)}
        row = 3 if active == "One" else 4
        attributes[(row, 4)] = 0x61
        return cls._snapshot(lines, attributes)

    def test_standalone_checkbox_is_focused_by_tab_and_set_idempotently(self) -> None:
        unfocused = self._checklist("Two", {"One": False, "Two": False})
        focused = self._checklist("One", {"One": False, "Two": False})
        checked = self._checklist("One", {"One": True, "Two": False})

        class Session(NewtSession):
            def __init__(self):
                self.current = unfocused
                self.pending = iter((focused, checked))
                self.keys = []

            def vga_screen(self, rows=None):
                return self.current

            def vga_wait_snapshot(self, predicate, *, timeout=None, rows=None, interval=None):
                self.current = next(self.pending)
                if not predicate(self.current):
                    raise AssertionError(
                        "expected standalone-checkbox transition was not observed"
                    )
                return self.current

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        NewtDialog(session).set_checkbox("One")
        self.assertEqual(session.keys, ["tab", "spc"])

    def test_checklist_batch_scans_once_for_all_requested_items(self) -> None:
        class Session(NewtSession):
            def __init__(self):
                self.frames = iter(
                    [
                        NewtDialogTests._checklist("One", {"One": False, "Two": False}),
                        NewtDialogTests._checklist("One", {"One": False, "Two": False}),
                        NewtDialogTests._checklist("One", {"One": True, "Two": False}),
                        NewtDialogTests._checklist("Two", {"One": True, "Two": False}),
                        NewtDialogTests._checklist("Two", {"One": True, "Two": True}),
                        NewtDialogTests._checklist("Two", {"One": True, "Two": True}),
                    ]
                )
                self.keys = []

            def vga_screen(self, rows=None):
                return next(self.frames)

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        with self.assertLogs("hostlib.newt_dialog", level="INFO") as captured:
            NewtDialog(session).set_checklist_items(["One", "Two"])
        self.assertEqual(session.keys, ["pgup", "spc", "down", "spc", "down"])
        self.assertEqual(
            [record.getMessage() for record in captured.records],
            ["✅ Select One", "✅ Select Two"],
        )

    def test_exhaustive_checklist_batch_clears_unlisted_entries(self) -> None:
        class Session(NewtSession):
            def __init__(self):
                self.frames = iter(
                    [
                        NewtDialogTests._checklist("One", {"One": True, "Two": True}),
                        NewtDialogTests._checklist("One", {"One": True, "Two": True}),
                        NewtDialogTests._checklist("Two", {"One": True, "Two": True}),
                        NewtDialogTests._checklist("Two", {"One": True, "Two": False}),
                        NewtDialogTests._checklist("Two", {"One": True, "Two": False}),
                    ]
                )
                self.keys = []

            def vga_screen(self, rows=None):
                return next(self.frames)

            def kb_press_quiet(self, *keys):
                self.keys.extend(keys)

        session = Session()
        with self.assertLogs("hostlib.newt_dialog", level="INFO") as captured:
            NewtDialog(session).set_checklist_items(["One"])
        self.assertEqual(session.keys, ["pgup", "down", "spc", "down"])
        self.assertEqual(
            [record.getMessage() for record in captured.records],
            ["☑️ Clear Two"],
        )


class MonitorTests(unittest.IsolatedAsyncioTestCase):
    async def test_disconnected_monitor_rejects_commands(self) -> None:
        from hostlib.qmp import QmpUnavailable

        monitor = Monitor(Path("missing.sock"))
        with self.assertRaisesRegex(QmpUnavailable, "not connected"):
            await monitor.execute("query-status")

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
        with temporary_root() as root:
            socket = root / "qmp.sock"
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
        with temporary_root() as root:
            directory = root
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
            vga=SimpleNamespace(
                capture=AsyncMock(),
                wait=AsyncMock(),
                invalidate=unittest.mock.Mock(),
            ),
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

    def test_text_wait_matches_a_title_inside_a_cp437_border(self) -> None:
        session = self.session()
        session.vga_wait("Select Color or Monochrome")
        predicate = session._runtime.vga.wait.call_args.args[0]
        self.assertTrue(predicate("┌──── Select Color or Monochrome ────┐"))

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
        session._runtime.vga.invalidate.reset_mock()
        session.kb_press_quiet("f12")
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
