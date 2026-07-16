"""Provide the narrow QMP interface used by VM automation and the ``qmp`` CLI.

The third-party client stays behind ``Monitor`` so connection retries, command
timeouts, HMP tunneling, key pacing, and test doubles have one project-owned
boundary.
"""

from __future__ import annotations

import asyncio
import logging
from pathlib import Path
from typing import Any

from .errors import RetroError

log = logging.getLogger(__name__)


class QmpUnavailable(RetroError):
    """Report a temporary failure to connect to QMP."""

    pass


class Monitor:
    """Small project-facing facade over the asynchronous QMP client.

    A monitor is disconnected until ``connect`` or ``async with`` succeeds.
    Commands share the configured timeout, while connection attempts also wait
    for QEMU to create the Unix socket.
    """

    def __init__(self, socket: Path, timeout: float = 5) -> None:
        """Initialize a monitor for one QMP Unix socket."""
        self.socket = socket
        self.timeout = timeout
        self._client: Any = None

    async def connect(self) -> None:
        """Retry until the QMP socket accepts a connection or times out.

        Raises:
            QmpUnavailable: If the dependency is absent or connection times out.
        """
        try:
            from qemu.qmp import ConnectError, QMPClient
        except ImportError as exc:
            raise QmpUnavailable(
                "qemu.qmp is required; install the Python project dependencies"
            ) from exc
        deadline = asyncio.get_running_loop().time() + self.timeout
        await self._connect_until(QMPClient, ConnectError, deadline)

    async def _connect_until(
        self, client_type: Any, connect_error: type[Exception], deadline: float
    ) -> None:
        """Retry QMP client connections until the monotonic deadline."""
        loop = asyncio.get_running_loop()
        last_error: BaseException | None = None
        while loop.time() < deadline:
            if not self.socket.exists():
                await asyncio.sleep(min(0.05, max(0, deadline - loop.time())))
                continue
            self._client = client_type("retro")
            try:
                async with asyncio.timeout(deadline - loop.time()):
                    await self._client.connect(str(self.socket))
                return
            except connect_error as exc:
                last_error = exc
                self._client = None
                await asyncio.sleep(min(0.05, max(0, deadline - loop.time())))
            except TimeoutError as exc:
                last_error = exc
                break
        raise QmpUnavailable(f"Timed out connecting to QMP at {self.socket}") from last_error

    async def close(self) -> None:
        """Disconnect the active QMP client."""
        client, self._client = self._client, None
        if client is not None:
            try:
                await client.disconnect()
            except EOFError:
                log.debug("QMP peer closed before disconnect completed")

    async def execute(self, command: str, arguments: dict[str, object] | None = None) -> Any:
        """Execute one QMP command with an optional argument mapping.

        Returns:
            The decoded command result supplied by ``qemu.qmp``.

        Raises:
            QmpUnavailable: If this monitor is not connected.
            TimeoutError: If QEMU does not answer within ``timeout``.
        """
        if self._client is None:
            raise QmpUnavailable("QMP is not connected")
        log.debug("QMP %s %s", command, arguments or "")
        async with asyncio.timeout(self.timeout):
            return await self._client.execute(command, arguments)

    async def hmp(self, command: str) -> str:
        """Execute a human-monitor command through QMP."""
        response = await self.execute("human-monitor-command", {"command-line": command})
        return response if isinstance(response, str) else ""

    async def send_key(self, key: str, *, hold_time: int = 10, interval: float = 0.02) -> None:
        """Send one QEMU key sequence and pause before the next request.

        Hyphen-separated qcodes form simultaneous modifiers, such as
        ``shift-a``. Per-key requests and the trailing interval prevent old
        guest keyboard controllers from being overrun.
        """
        await self.execute(
            "send-key",
            {
                "keys": [{"type": "qcode", "data": part} for part in key.split("-")],
                "hold-time": hold_time,
            },
        )
        await asyncio.sleep(interval)

    @property
    def events(self) -> Any:
        """Return the underlying QMP event queue."""
        if self._client is None:
            raise QmpUnavailable("QMP is not connected")
        return self._client.events

    async def __aenter__(self) -> "Monitor":
        """Connect this monitor and return it as an asynchronous context manager."""
        await self.connect()
        return self

    async def __aexit__(self, *_: object) -> None:
        """Close the monitor when leaving an asynchronous context."""
        await self.close()
