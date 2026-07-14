from __future__ import annotations

import asyncio
from enum import Enum
import logging
from pathlib import Path
import re
import shlex
import time
from typing import Any, Coroutine, TypeVar

from ..qmp import Monitor
from .keyboard import encode
from .serial import SerialConsole
from .vga import ScreenObserver

log = logging.getLogger(__name__)
T = TypeVar("T")


class Match(Enum):
    TEXT = "text"
    LINE = "line"
    REGEX = "regex"


class _InstallRuntime:
    """Event-loop-owned transports hidden behind the synchronous public API."""

    def __init__(self, monitor: Monitor, qemu_dir: Path) -> None:
        self.monitor = monitor
        self.vga = ScreenObserver(monitor, qemu_dir)
        self.serial = SerialConsole(qemu_dir / "ttyS3.sock")

    async def start(self) -> None:
        await self.vga.start()
        await self.serial.start()

    async def close(self) -> None:
        await self.vga.close()
        await self.serial.close()


class Serial:
    def __init__(self, session: "InstallSession") -> None:
        self._session = session

    def send(self, text: str) -> None:
        self._session._call(self._session._runtime.serial.send(text))

    def wait(
        self,
        expected: str,
        *,
        line: bool = False,
        regex: bool = False,
        timeout: float | None = None,
    ) -> str:
        return self._session._call(
            self._session._runtime.serial.wait(expected, line=line, regex=regex, timeout=timeout)
        )

    def prompt(self, *questions: str, answer: str, regex: bool = False) -> None:
        self._session._call(
            self._session._runtime.serial.prompt(*questions, answer=answer, regex=regex)
        )

    def wait_any(
        self, *patterns: str, regex: bool = False, timeout: float | None = None
    ) -> tuple[int, str]:
        return self._session._call(
            self._session._runtime.serial.wait_any(patterns, regex=regex, timeout=timeout)
        )

    def read_until(self, pattern: re.Pattern[str]) -> str:
        return self._session._call(self._session._runtime.serial.read_until(pattern))

    def mark(self) -> int:
        return self._session._call(self._session._runtime.serial.mark())

    def rewind(self, offset: int) -> None:
        self._session._call(self._session._runtime.serial.rewind(offset))


class InstallSession:
    """Synchronous public API for Python install manifests."""

    postinst_command = (
        "if [ ! -d /retro/guestlib.d ]; then mkdir -p /retro && "
        "mount -t msdos /dev/hdb1 /retro; fi; /retro/guestlib.d/postinst.sh"
    )

    def __init__(self, runtime: _InstallRuntime, loop: asyncio.AbstractEventLoop) -> None:
        from .dialog import Dialog

        self._runtime = runtime
        self._loop = loop
        self.serial = Serial(self)
        self.dialog = Dialog(self.serial)

    @property
    def qemu_dir(self) -> Path:
        return self._runtime.vga.qemu_dir

    def _call(self, coroutine: Coroutine[Any, Any, T]) -> T:
        return asyncio.run_coroutine_threadsafe(coroutine, self._loop).result()

    def vga_wait(
        self, *expected: str, match: Match = Match.TEXT, timeout: float | None = None
    ) -> None:
        for value in expected:
            log.info("⏳ %s", value)
            if match is Match.TEXT:
                predicate = lambda screen, value=value: value in screen
            elif match is Match.LINE:
                predicate = lambda screen, value=value: any(
                    line.strip() == value.strip() for line in screen.splitlines()
                )
            else:
                expression = re.compile(value)
                predicate = lambda screen, expression=expression: any(
                    expression.search(line) for line in screen.splitlines()
                )
            self._call(self._runtime.vga.wait(predicate, timeout))
            log.info("🖥️  %s", value)

    def kb_press(self, *keys: str) -> None:
        log.info("👇 %s", " ".join(keys))
        self._send_keys(keys)

    def _send_keys(self, keys: tuple[str, ...] | list[str]) -> None:
        for key in keys:
            self._call(self._runtime.monitor.send_key(key))
            if "ret" in key.split("-"):
                self._runtime.vga.invalidate()

    def kb_repeat(self, key: str, count: int = 1) -> None:
        log.info("👇 %s%s", key, f" ({count} times)" if count > 1 else "")
        self._send_keys([key] * count)

    def kb_type(self, text: str, *, enter: bool = False) -> None:
        keys = encode(text)
        if enter:
            keys.append("ret")
            log.info("⌨️  %s ↩️", text)
        self._send_keys(keys)

    def change_image(self, image: str, device: str = "floppy0", format: str = "raw") -> None:
        log.info("💾 Inserting %r", image)
        self._call(self._runtime.monitor.hmp(f"change {device} {image} {format}"))

    def change_floppy(self, image: str) -> None:
        self.change_image(image)
        time.sleep(1)

    def eject_disk(self, device: str = "floppy0") -> None:
        log.info("⏏️  Ejecting %s", device)
        self._call(self._runtime.monitor.hmp(f"eject {device}"))

    def set_boot(self, disk: str) -> None:
        log.info("🥾 Set boot device to %s", disk)
        self._call(self._runtime.monitor.hmp(f"boot_set {disk}"))

    def serial_shell_start(self, *, screen_prompt: str = "#", serial_prompt: str = "#") -> None:
        device = "/dev/ttyS3"
        launcher = (
            f"[ -c {device} ] || mknod {device} c 4 67; "
            f"PS1={shlex.quote(serial_prompt + ' ')} sh -i <{device} >{device} 2>{device}"
        )
        self.vga_wait(screen_prompt, match=Match.LINE)
        self.kb_type(launcher, enter=True)
        self.serial.wait(serial_prompt, line=True)

    def serial_shell_send(self, command: str, *, wait: bool = True, prompt: str = "#") -> None:
        self.serial.send(command)
        if wait:
            self.serial.wait(prompt, line=True)

    def serial_shell_exit(self, *, screen_prompt: str = "#") -> None:
        self.serial.send("exit")
        self.vga_wait(screen_prompt, match=Match.LINE)

    def serial_console_echo(self, message: str) -> None:
        self.serial_shell_send(f"echo {shlex.quote(message)} >/dev/console")

    def run_postinst(
        self, password: str | None = None, *, login: str = "login:", shell: str = "#"
    ) -> None:
        self.vga_wait(login, match=Match.LINE)
        self.kb_type("root", enter=True)
        if password is not None:
            self.vga_wait("Password:")
            self.kb_type(password, enter=True)
        self.vga_wait(shell, match=Match.LINE)
        self.kb_type(self.postinst_command, enter=True)


async def run_install(
    monitor: Monitor,
    qemu_dir: Path,
    entrypoint: Any,
) -> None:
    runtime = _InstallRuntime(monitor, qemu_dir)
    await runtime.start()
    try:
        session = InstallSession(runtime, asyncio.get_running_loop())
        await asyncio.to_thread(entrypoint, session)
    finally:
        await runtime.close()
