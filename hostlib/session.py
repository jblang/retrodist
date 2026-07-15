"""Bridge synchronous installer drivers to event-loop-owned VM transports.

QEMU, QMP, VGA polling, and serial I/O remain asynchronous on the main event
loop. Family drivers run in a worker thread and use ``InstallSession`` as a
synchronous API, keeping release automation linear and readable without moving
async concerns into every installer step.
"""

from __future__ import annotations

import asyncio
from enum import Enum
import logging
from pathlib import Path
import re
import shlex
import time
from typing import Any, Coroutine, TypeVar

from .config import RetroConfig
from .qmp import Monitor
from .keyboard import encode
from .serial import SerialConsole
from .vga import ScreenObserver

log = logging.getLogger(__name__)
T = TypeVar("T")


class Match(Enum):
    """Select how installer screen text is matched."""

    TEXT = "text"
    LINE = "line"
    REGEX = "regex"


class _InstallRuntime:
    """Own the asynchronous transports hidden behind ``InstallSession``.

    The QMP monitor is supplied by the QEMU lifecycle. This object adds the VGA
    observer and dedicated ``ttyS3`` automation console and closes them as a
    unit when installation ends or fails.
    """

    def __init__(self, monitor: Monitor, qemu_dir: Path) -> None:
        """Create the asynchronous transports for one installer VM."""
        self.monitor = monitor
        self.vga = ScreenObserver(monitor, qemu_dir)
        self.serial = SerialConsole(qemu_dir / "ttyS3.sock")

    async def start(self) -> None:
        """Start VGA observation and the automation serial console."""
        await self.vga.start()
        await self.serial.start()

    async def close(self) -> None:
        """Close VGA and serial transports."""
        await self.vga.close()
        await self.serial.close()


class Serial:
    """Expose synchronous serial operations to installer drivers.

    Every call is submitted to the runtime's owning event loop through the
    parent session. The API mirrors ``SerialConsole`` closely enough to satisfy
    dialog and fdisk protocol drivers without exposing coroutines.
    """

    def __init__(self, session: "InstallSession") -> None:
        """Bind the synchronous serial facade to an installer session."""
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
        self, *patterns: str, regex: bool = False, timeout: float | None = None
    ) -> tuple[int, str]:
        """Synchronously wait for any configured serial pattern."""
        return self._session._call(
            self._session._runtime.serial.wait_any(patterns, regex=regex, timeout=timeout)
        )

    def read_until(self, pattern: re.Pattern[str]) -> str:
        """Consume serial input through a regular-expression match."""
        return self._session._call(self._session._runtime.serial.read_until(pattern))

    def mark(self) -> int:
        """Return the current serial buffer position."""
        return self._session._call(self._session._runtime.serial.mark())

    def rewind(self, offset: int) -> None:
        """Restore a prior serial buffer position."""
        self._session._call(self._session._runtime.serial.rewind(offset))


class InstallSession:
    """Synchronous VM-control API used by declarative plans and family drivers.

    The session combines serial prompt matching, VGA observation, paced QMP
    keyboard input, removable-media control, boot-device changes, interactive
    serial shells, option binding, and post-install login. Calls block only the
    installer worker thread; the transport event loop continues running.
    """

    def __init__(
        self,
        runtime: _InstallRuntime,
        loop: asyncio.AbstractEventLoop,
        config: RetroConfig,
    ) -> None:
        """Bind synchronous driver APIs to an event-loop-owned runtime."""
        from .dialog import Dialog

        self._runtime = runtime
        self._loop = loop
        self.config = config
        self.serial = Serial(self)
        self.dialog = Dialog(self.serial)

    def options(self, cls: type[T]) -> T:
        """Build the requested installer options from resolved TOML values."""
        return self.config.options(cls)

    @property
    def postinst_command(self) -> str:
        """Return the guest command that mounts FAT media and runs post-installation.

        The mount device and path come from installer options so distributions
        with nonstandard disk layouts use the same global guest runner.
        """
        values = self.config.install_values
        mount = str(values.get("fat_mount", "/retro"))
        partition = str(values.get("fat_partition", "/dev/hdb1"))
        return (
            f"if [ ! -d {shlex.quote(mount)}/guestlib.d ]; then "
            f"mkdir -p {shlex.quote(mount)} && mount -t msdos "
            f"{shlex.quote(partition)} {shlex.quote(mount)}; fi; "
            f"{shlex.quote(mount)}/guestlib.d/postinst.sh"
        )

    @property
    def qemu_dir(self) -> Path:
        """Return the active VM's generated-state directory."""
        return self._runtime.vga.qemu_dir

    def _call(self, coroutine: Coroutine[Any, Any, T]) -> T:
        """Run a transport coroutine on the owning event loop and return its result."""
        return asyncio.run_coroutine_threadsafe(coroutine, self._loop).result()

    def vga_wait(
        self, *expected: str, match: Match = Match.TEXT, timeout: float | None = None
    ) -> None:
        """Wait for one or more VGA strings using the selected match mode.

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

    def kb_press(self, *keys: str) -> None:
        """Send literal QEMU key sequences and log them.

        Each argument is one QEMU qcode sequence; modifiers within a sequence
        are hyphen-separated.
        """
        log.info("👇 %s", " ".join(keys))
        self._send_keys(keys)

    def _send_keys(self, keys: tuple[str, ...] | list[str]) -> None:
        """Send paced keys and invalidate VGA state after Enter."""
        for key in keys:
            self._call(self._runtime.monitor.send_key(key))
            if "ret" in key.split("-"):
                self._runtime.vga.invalidate()

    def kb_repeat(self, key: str, count: int = 1) -> None:
        """Send one literal key a configured number of times."""
        log.info("👇 %s%s", key, f" ({count} times)" if count > 1 else "")
        self._send_keys([key] * count)

    def kb_type(self, text: str) -> None:
        """Encode and type text through individual paced QMP key requests.

        Newline and tab characters become Enter and Tab. Sending each key as a
        separate request is intentional for early guest keyboard controllers.
        """
        if text.endswith("\n") and "\n" not in text[:-1]:
            log.info("⌨️  %s ↩️", text[:-1])
        else:
            log.info("⌨️  %s", text.replace("\t", r"\t").replace("\n", r"\n"))
        self._send_keys(encode(text))

    def change_image(self, image: str, device: str = "floppy0", format: str = "raw") -> None:
        """Insert a removable-media image through the QEMU monitor."""
        log.info("💾 Inserting %r", image)
        self._call(self._runtime.monitor.hmp(f"change {device} {image} {format}"))

    def change_floppy(self, image: str) -> None:
        """Insert a floppy image and allow the guest time to detect it."""
        self.change_image(image)
        time.sleep(1)

    def eject_disk(self, device: str = "floppy0") -> None:
        """Eject a removable device through the QEMU monitor."""
        log.info("⏏️  Ejecting %s", device)
        self._call(self._runtime.monitor.hmp(f"eject {device}"))

    def set_boot(self, disk: str) -> None:
        """Set QEMU's next boot device."""
        log.info("🥾 Set boot device to %s", disk)
        self._call(self._runtime.monitor.hmp(f"boot_set {disk}"))

    def serial_shell_start(self, *, screen_prompt: str = "#", serial_prompt: str = "#") -> None:
        """Redirect an interactive guest shell to the automation serial port.

        The launcher is typed at the visible console, creates ``/dev/ttyS3``
        when necessary, and redirects all shell streams to that device.
        """
        device = "/dev/ttyS3"
        launcher = (
            f"[ -c {device} ] || mknod {device} c 4 67; "
            f"PS1={shlex.quote(serial_prompt + ' ')} sh -i <{device} >{device} 2>{device}"
        )
        self.vga_wait(screen_prompt, match=Match.LINE)
        self.kb_type(f"{launcher}\n")
        self.serial.wait(serial_prompt, line=True)

    def serial_shell_send(self, command: str, *, wait: bool = True, prompt: str = "#") -> None:
        """Run one command in the active serial shell."""
        self.serial.send(command)
        if wait:
            self.serial.wait(prompt, line=True)

    def serial_shell_exit(self, *, screen_prompt: str = "#") -> None:
        """Exit the serial shell and wait for the visible console."""
        self.serial.send("exit")
        self.vga_wait(screen_prompt, match=Match.LINE)

    def serial_console_echo(self, message: str) -> None:
        """Write a message to the guest's visible console."""
        self.serial_shell_send(f"echo {shlex.quote(message)} >/dev/console")

    def run_postinst(
        self, password: str | None = None, *, login: str = "login:", shell: str = "#"
    ) -> None:
        """Log in as root and launch the staged post-installation runner.

        Args:
            password: Optional root password required after the login name.
            login: Complete-line login prompt to wait for.
            shell: Complete-line root shell prompt to wait for.
        """
        self.vga_wait(login, match=Match.LINE)
        self.kb_type("root\n")
        if password is not None:
            self.vga_wait("Password:")
            self.kb_type(f"{password}\n")
        self.vga_wait(shell, match=Match.LINE)
        self.kb_type(f"{self.postinst_command}\n")


async def run_install(
    monitor: Monitor,
    qemu_dir: Path,
    config: RetroConfig,
) -> None:
    """Run one installer driver while owning its asynchronous transports.

    The driver executes in a worker thread so its synchronous waits do not block
    QMP or serial receipt. Transport cleanup is guaranteed even when validation
    or installer automation raises an exception.
    """
    from .installers import run_configured_install

    runtime = _InstallRuntime(monitor, qemu_dir)
    await runtime.start()
    try:
        session = InstallSession(runtime, asyncio.get_running_loop(), config)
        await asyncio.to_thread(run_configured_install, session)
    finally:
        await runtime.close()
