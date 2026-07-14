from __future__ import annotations

import asyncio
import logging
from pathlib import Path
from typing import Any

from .errors import RetroError

log = logging.getLogger(__name__)


class QmpUnavailable(RetroError):
    pass


class Monitor:
    """Small project-facing facade over the official asynchronous QMP client."""

    def __init__(self, socket: Path, timeout: float = 5) -> None:
        self.socket = socket
        self.timeout = timeout
        self._client: Any = None

    async def connect(self) -> None:
        try:
            from qemu.qmp import ConnectError, QMPClient
        except ImportError as exc:
            raise QmpUnavailable(
                "qemu.qmp is required; install the Python project dependencies"
            ) from exc
        loop = asyncio.get_running_loop()
        deadline = loop.time() + self.timeout
        last_error: BaseException | None = None
        while loop.time() < deadline:
            if not self.socket.exists():
                await asyncio.sleep(min(0.05, max(0, deadline - loop.time())))
                continue
            self._client = QMPClient("retro")
            try:
                async with asyncio.timeout(deadline - loop.time()):
                    await self._client.connect(str(self.socket))
                return
            except ConnectError as exc:
                last_error = exc
                self._client = None
                await asyncio.sleep(min(0.05, max(0, deadline - loop.time())))
            except TimeoutError as exc:
                last_error = exc
                break
        raise QmpUnavailable(f"Timed out connecting to QMP at {self.socket}") from last_error

    async def close(self) -> None:
        client, self._client = self._client, None
        if client is not None:
            try:
                await client.disconnect()
            except EOFError:
                log.debug("QMP peer closed before disconnect completed")

    async def execute(self, command: str, arguments: dict[str, object] | None = None) -> Any:
        if self._client is None:
            raise QmpUnavailable("QMP is not connected")
        log.debug("QMP %s %s", command, arguments or "")
        async with asyncio.timeout(self.timeout):
            return await self._client.execute(command, arguments)

    async def hmp(self, command: str) -> str:
        response = await self.execute("human-monitor-command", {"command-line": command})
        return response if isinstance(response, str) else ""

    async def send_key(self, key: str, *, hold_time: int = 10, interval: float = 0.02) -> None:
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
        if self._client is None:
            raise QmpUnavailable("QMP is not connected")
        return self._client.events

    async def __aenter__(self) -> "Monitor":
        await self.connect()
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.close()
