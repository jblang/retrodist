"""Expose synchronous QEMU scripting over event-loop-owned VM transports."""

from __future__ import annotations

import asyncio
from enum import Enum
import logging
from pathlib import Path
import re
import shlex
import time
from typing import Any, Callable, Coroutine, TypeVar

from .qmp import Monitor, encode_key
from .serial import SerialConsole
from .vga import ScreenObserver, ScreenSnapshot

log = logging.getLogger(__name__)
T = TypeVar("T")


class Match(Enum):
    """Select how VGA screen text is matched."""

    TEXT = "text"
    LINE = "line"
    REGEX = "regex"


class _QemuSessionRuntime:
    """Own the asynchronous transports hidden behind ``QemuSession``.

    The QMP monitor is supplied by the QEMU lifecycle. This object adds the VGA
    observer and owns the dedicated ``ttyS3`` automation console.
    """

    def __init__(self, monitor: Monitor, qemu_dir: Path) -> None:
        """Create the asynchronous transports for one scripted VM."""
        self.monitor = monitor
        self.vga = ScreenObserver(monitor, qemu_dir)
        self.serial = SerialConsole(qemu_dir / "ttyS3.sock")

    async def start(self) -> None:
        """Start the automation serial console."""
        await self.serial.start()

    async def close(self) -> None:
        """Close the automation serial console."""
        await self.serial.close()


class Serial:
    """Expose synchronous serial operations to QEMU scripts.

    Every call is submitted to the runtime's owning event loop through the
    parent session. The API mirrors ``SerialConsole`` closely enough to satisfy
    dialog and fdisk protocol drivers without exposing coroutines.
    """

    def __init__(self, session: "QemuSession") -> None:
        """Bind the synchronous serial facade to a QEMU session."""
        self._session = session

    def send(self, text: str) -> None:
        """Synchronously send text through the automation serial port."""
        self._session._call(self._session._runtime.serial.send(text))

    def wait(
        self,
        expected: str,
        *,
        line: bool = False,
        regex: bool = False,
        timeout: float | None = None,
    ) -> str:
        """Synchronously wait for one serial prompt."""
        return self._session._call(
            self._session._runtime.serial.wait(expected, line=line, regex=regex, timeout=timeout)
        )

    def prompt(self, *questions: str, answer: str, regex: bool = False) -> None:
        """Synchronously answer a sequence of serial prompts."""
        self._session._call(
            self._session._runtime.serial.prompt(*questions, answer=answer, regex=regex)
        )

    def wait_any(
        self, *patterns: str | re.Pattern[str], regex: bool = False, timeout: float | None = None
    ) -> tuple[int, str]:
        """Synchronously wait for any configured serial pattern."""
        return self._session._call(
            self._session._runtime.serial.wait_any(patterns, regex=regex, timeout=timeout)
        )

    def answer_any(self, prompts: list[tuple[str, str, bool]]) -> None:
        """Answer configured prompts in whichever order the guest presents them."""
        pending = list(prompts)
        while pending:
            patterns: tuple[str | re.Pattern[str], ...] = tuple(
                re.compile(expect, re.MULTILINE) if regex else expect
                for expect, _, regex in pending
            )
            index, _ = self.wait_any(*patterns)
            _, answer, _ = pending.pop(index)
            self.send(answer)

    def read_until(self, pattern: re.Pattern[str]) -> str:
        """Consume serial input through a regular-expression match."""
        return self._session._call(self._session._runtime.serial.read_until(pattern))

    def mark(self) -> int:
        """Return the current serial buffer position."""
        return self._session._call(self._session._runtime.serial.mark())

    def rewind(self, offset: int) -> None:
        """Restore a prior serial buffer position."""
        self._session._call(self._session._runtime.serial.rewind(offset))


class QemuSession:
    """Synchronous VM-control API for QEMU scripts.

    The session combines serial prompt matching, VGA observation, paced QMP
    keyboard input, removable-media control, boot-device changes, and
    interactive serial shells. Calls block only the caller's worker thread;
    the transport event loop continues running.
    """

    def __init__(
        self,
        runtime: _QemuSessionRuntime,
        loop: asyncio.AbstractEventLoop,
    ) -> None:
        """Bind synchronous QEMU controls to an event-loop-owned runtime."""
        self._runtime = runtime
        self._loop = loop
        self.serial = Serial(self)

    @property
    def qemu_dir(self) -> Path:
        """Return the active VM's generated-state directory."""
        return self._runtime.vga.qemu_dir

    def _call(self, coroutine: Coroutine[Any, Any, T]) -> T:
        """Run a transport coroutine on the owning event loop and return its result."""
        return asyncio.run_coroutine_threadsafe(coroutine, self._loop).result()

    def vga_wait(
        self,
        *expected: str,
        match: Match = Match.TEXT,
        timeout: float | None = None,
    ) -> None:
        """Wait for VGA strings in the full text screen.

        Args:
            *expected: Screen values to match sequentially.
            match: Substring, complete-line, or per-line regular-expression mode.
            timeout: Optional timeout applied separately to each value.
        """
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

    def vga_screen(self, rows: int | None = None) -> ScreenSnapshot:
        """Capture raw VGA cells for local dialog parsing."""
        return self._call(self._runtime.vga.capture(rows))

    def vga_wait_snapshot(
        self,
        predicate: Callable[[ScreenSnapshot], bool],
        *,
        timeout: float | None = None,
        rows: int | None = None,
        interval: float | None = None,
    ) -> ScreenSnapshot:
        """Wait for and return the VGA snapshot satisfying ``predicate``."""
        return self._call(
            self._runtime.vga.wait_snapshot(
                predicate,
                timeout,
                rows=rows,
                interval=interval,
            )
        )

    def kb_press(self, *keys: str) -> None:
        """Send literal QEMU key sequences and log them.

        Each argument is one QEMU qcode sequence; modifiers within a sequence
        are hyphen-separated.
        """
        log.info("👇 %s", " ".join(keys))
        self._send_keys(keys)

    def kb_press_quiet(self, *keys: str) -> None:
        """Send QEMU keys for a higher-level controller that owns logging."""
        self._send_keys(keys)

    def _send_keys(self, keys: tuple[str, ...] | list[str]) -> None:
        """Send paced keys and invalidate VGA state after screen activation."""
        for key in keys:
            self._call(self._runtime.monitor.send_key(key))
            if {"ret", "f12"} & set(key.split("-")):
                self._runtime.vga.invalidate()

    def kb_type(self, text: str) -> None:
        """Encode and type text through individual paced QMP key requests.

        Newline and tab characters become Enter and Tab. Sending each key as a
        separate request is intentional for early guest keyboard controllers.
        """
        if text.endswith("\n") and "\n" not in text[:-1]:
            log.info("⌨️  %s ↩️", text[:-1])
        else:
            log.info("⌨️  %s", text.replace("\t", r"\t").replace("\n", r"\n"))
        self._send_keys(encode_key(text))

    def kb_type_quiet(self, text: str) -> None:
        """Type text for a higher-level controller that owns logging."""
        self._send_keys(encode_key(text))

    def boot_command(self, prompt: str, command: str = "") -> None:
        """Wait for a boot prompt and type the configured kernel command line."""
        self.vga_wait(prompt, match=Match.LINE)
        self.kb_type(f"{command}\n")

    def change_floppy(self, image: str) -> None:
        """Insert a floppy image and allow the guest time to detect it."""
        log.info("💾 Inserting %r", image)
        self._call(self._runtime.monitor.hmp(f"change floppy0 {image} raw"))
        time.sleep(1)

    def set_boot(self, disk: str) -> None:
        """Set QEMU's next boot device."""
        log.info("🥾 Set boot device to %s", disk)
        self._call(self._runtime.monitor.hmp(f"boot_set {disk}"))

    def serial_shell_start(
        self,
        *,
        screen_prompt: str = "#",
        serial_prompt: str = "#",
        screen_match: Match = Match.LINE,
    ) -> None:
        """Redirect an interactive guest shell to the automation serial port.

        The launcher is typed at the visible console, creates ``/dev/ttyS3``
        when necessary, and redirects all shell streams to that device.
        """
        device = "/dev/ttyS3"
        launcher = (
            f"[ -c {device} ] || mknod {device} c 4 67; "
            f"PS1={shlex.quote(serial_prompt + ' ')} sh -i <{device} >{device} 2>{device}"
        )
        self.vga_wait(screen_prompt, match=screen_match)
        self.kb_type(f"{launcher}\n")
        self.serial.wait(serial_prompt, line=True)

    def serial_shell_send(self, command: str, *, wait: bool = True, prompt: str = "#") -> None:
        """Run one command in the active serial shell."""
        self.serial.send(command)
        if wait:
            self.serial.wait(prompt, line=True)

    def serial_shell_exit(
        self, *, screen_prompt: str = "#", screen_match: Match = Match.LINE
    ) -> None:
        """Exit the serial shell and wait for the visible console."""
        self.serial.send("exit")
        self.vga_wait(screen_prompt, match=screen_match)

    def serial_console_echo(self, message: str) -> None:
        """Write a message to the guest's visible console."""
        self.serial_shell_send(f"echo {shlex.quote(message)} >/dev/console")


async def run_script(
    monitor: Monitor,
    qemu_dir: Path,
    script: Callable[[QemuSession], T],
) -> T:
    """Run a synchronous QEMU script while owning its asynchronous transports."""
    runtime = _QemuSessionRuntime(monitor, qemu_dir)
    await runtime.start()
    try:
        session = QemuSession(runtime, asyncio.get_running_loop())
        return await asyncio.to_thread(script, session)
    finally:
        await runtime.close()
