from __future__ import annotations

import asyncio
import ast
from pathlib import Path
import shlex
import tempfile
from types import SimpleNamespace
from types import ModuleType
import unittest
from unittest.mock import AsyncMock
from unittest.mock import patch
import re
import sys

from retro_host.config import QemuConfig
from retro_host.context import Context
from retro_host.install.keyboard import encode
from retro_host.install.dialog import Choice, Dialog
from retro_host.install.session import InstallSession, Match
from retro_host.install.serial import SerialConsole
from retro_host.install.drivers.slackware import Pkgtool
from retro_host.install.drivers.slackware_early import Sysinstall
from retro_host.install.vga import Screen, ScreenObserver, decode
from retro_host.media import MediaStager, legacy_extraction
from retro_host.qmp import Monitor


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


class ConfigTests(unittest.TestCase):
    def test_profile_only_fills_unspecified_values(self) -> None:
        config = QemuConfig(profile="linux-2.0", ram="32M")
        config.apply_profile()
        self.assertEqual(config.ram, "32M")
        self.assertEqual(config.disk_size, "8G")
        self.assertEqual(config.vga, "cirrus")


class KeyboardTests(unittest.TestCase):
    def test_encode(self) -> None:
        self.assertEqual(encode("Ab c?"), ["shift-a", "b", "spc", "c", "shift-slash"])

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
        return self.text[start:self.offset]

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
        Pkgtool(SimpleNamespace(dialog=dialog))._configure()
        self.assertEqual(serial.answers, ["yes", "ok", "ok"])

    def test_none_answer_leaves_lookahead_for_outer_dispatch(self) -> None:
        def screen(item: str) -> str:
            return (
                "TITLE: Main\nTYPE: menu\n"
                f"ITEM: Next :: {item}\nRESPONSE:\n"
            )

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


class PkgtoolPromptTests(unittest.TestCase):
    def test_python_driver_covers_every_fixed_shell_prompt(self) -> None:
        """Keep the Python dispatch table aligned with the original driver."""
        root = Path(__file__).resolve().parent.parent
        shell = (root / "slackware/pkgtool.sh").read_text()
        python = (root / "retro_host/install/drivers/slackware.py").read_text()

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
            Sysinstall(session)._packages()

            image = Path(temporary) / "bootdisk.img"
            self.assertEqual(image.stat().st_size, 1440 * 1024)
            session.change_floppy.assert_called_once_with("bootdisk.img")
            serial.send.assert_any_call("")


class ManifestCoverageTests(unittest.TestCase):
    def test_every_install_shell_manifest_has_python_entrypoint(self) -> None:
        root = Path(__file__).resolve().parent.parent
        scripts = (
            script
            for family in ("slackware", "redhat", "debian")
            for script in (root / family).glob("**/install.sh")
        )
        for script in scripts:
            directory = script.parent
            while directory != root:
                if (directory / "install.py").is_file():
                    break
                directory = directory.parent
            else:
                self.fail(f"No install.py for {script.relative_to(root)}")

    def test_declarative_extract_shell_is_read_without_execution(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            config = root / "slackware/1.0/official"
            config.mkdir(parents=True)
            manifest = config / "extract.sh"
            manifest.write_text(
                "EXTRACT_SOURCE=disc1.iso\n"
                "BASE=bootdsks.144\n"
                "EXTRACT_BOOT_IMAGE=$BASE/bare.i\n"
                "EXTRACT_EXTRA_IMAGES=($BASE/net.i)\n"
                "extract_install_files\n"
            )
            context = Context.create(root, "extract", str(config))
            extraction = legacy_extraction(manifest, context)
            self.assertEqual(extraction.source, "disc1.iso")
            self.assertEqual(extraction.boot_image, "bootdsks.144/bare.i")
            self.assertEqual(extraction.extra_images, ["bootdsks.144/net.i"])

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
    async def test_send_key_uses_structured_qmp_key_events(self) -> None:
        monitor = Monitor(Path("unused.sock"))
        monitor.execute = AsyncMock()
        with patch("retro_host.qmp.asyncio.sleep", AsyncMock()) as sleep:
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
    async def test_wait_consumes_prompt_padding_before_next_anchored_regex(self) -> None:
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
            with self.assertLogs("retro_host.install.serial", "INFO") as transcript:
                await console._drain()
                await console.wait("# ")
                await console.close()
            self.assertEqual((directory / "ttyS3.log").read_bytes(), b"guest output\r\n# ")
            self.assertTrue(any("➡️  guest output" in line for line in transcript.output))
            self.assertTrue(any("✅ # " in line for line in transcript.output))


class SessionTests(unittest.TestCase):
    def session(self):
        runtime = SimpleNamespace(
            monitor=AsyncMock(),
            vga=SimpleNamespace(wait=AsyncMock(), invalidate=unittest.mock.Mock()),
        )
        session = InstallSession(runtime, None)
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
        session.kb_type("Ab", enter=True)
        self.assertEqual(
            [call.args[0] for call in session._runtime.monitor.send_key.await_args_list],
            ["shift-a", "b", "ret"],
        )
        session._runtime.vga.invalidate.assert_called_once_with()


if __name__ == "__main__":
    unittest.main()
