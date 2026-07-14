from __future__ import annotations

import asyncio
from collections import deque
from dataclasses import dataclass
import logging
from pathlib import Path
import re
import tempfile
from time import monotonic
from typing import Callable

from ..qmp import Monitor

log = logging.getLogger(__name__)


def decode(memory: bytes, columns: int = 80, rows: int | None = 25) -> str:
    characters = memory[0 : None if rows is None else columns * rows * 2 : 2]
    text = "".join(chr(byte) if 32 <= byte < 127 else " " for byte in characters)
    return "\n".join(text[index : index + columns] for index in range(0, len(text), columns))


@dataclass(frozen=True, slots=True)
class Screen:
    timestamp: float
    text: str


class ScreenObserver:
    """Read VGA memory on demand while a caller is waiting for a screen."""

    def __init__(
        self,
        monitor: Monitor,
        qemu_dir: Path,
        *,
        address: int = 0xB8000,
        memory_bytes: int = 32768,
        columns: int = 80,
        rows: int = 25,
        interval: float = 0.25,
    ) -> None:
        self.monitor = monitor
        self.qemu_dir = qemu_dir
        self.address = address
        self.memory_bytes = memory_bytes
        self.columns = columns
        self.rows = rows
        self.interval = interval
        self.history: deque[Screen] = deque(maxlen=100)
        self._stale: str | None = None

    @property
    def current(self) -> str:
        return self.history[-1].text if self.history else ""

    async def start(self) -> None:
        pass

    async def close(self) -> None:
        pass

    def invalidate(self) -> None:
        """Require the next wait to observe a screen change before matching."""
        self._stale = self.current

    async def _read(self) -> str:
        with tempfile.NamedTemporaryFile(dir=self.qemu_dir, delete=False) as stream:
            dump = Path(stream.name)
        dump.unlink()
        try:
            await self.monitor.hmp(
                f"pmemsave {self.address:#x} {self.memory_bytes} {dump.name}"
            )
            return decode(dump.read_bytes(), self.columns, None)
        finally:
            dump.unlink(missing_ok=True)

    async def wait(self, predicate: Callable[[str], bool], timeout: float | None) -> str:
        async def read() -> str:
            text = await self._read()
            if text != self.current:
                self.history.append(Screen(monotonic(), text))
            return text

        while True:
            text = await read()
            if self._stale is None or text != self._stale:
                self._stale = None
                break
            await asyncio.sleep(min(self.interval, 0.01))

        async def waiting() -> str:
            nonlocal text
            while True:
                if predicate(text):
                    return text
                await asyncio.sleep(self.interval)
                text = await read()

        if timeout is None:
            return await waiting()
        async with asyncio.timeout(timeout):
            return await waiting()
