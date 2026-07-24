"""Observe VGA text screens by reading guest memory through QMP.

The observer is demand-driven: each wait dumps VGA memory with ``pmemsave``,
decodes character bytes, and records changed screens. Invalidation prevents a
prompt that was just answered from matching again before the guest redraws.
"""

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

from .qmp import Monitor

log = logging.getLogger(__name__)


def decode(memory: bytes, columns: int = 80, rows: int | None = 25) -> str:
    """Decode interleaved VGA character/attribute bytes into text rows.

    Non-printable character bytes become spaces and attribute bytes are
    discarded. Passing ``rows=None`` decodes the complete supplied range.
    """
    characters = memory[0 : None if rows is None else columns * rows * 2 : 2]
    text = "".join(chr(byte) if 32 <= byte < 127 else " " for byte in characters)
    return "\n".join(text[index : index + columns] for index in range(0, len(text), columns))


@dataclass(frozen=True, slots=True)
class Screen:
    """Represent decoded VGA text rows."""

    timestamp: float
    text: str


class ScreenObserver:
    """Read VGA memory on demand while a caller waits for a screen predicate.

    Recent distinct screens are retained with monotonic timestamps for future
    diagnostics.
    """

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
        """Initialize VGA memory geometry, polling, and screen history."""
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
        """Return the most recently observed VGA text."""
        return self.history[-1].text if self.history else ""

    def invalidate(self) -> None:
        """Require the next wait to observe a screen change before matching."""
        self._stale = self.current

    async def _read(self) -> str:
        """Dump and decode the configured VGA text-memory range."""
        with tempfile.NamedTemporaryFile(dir=self.qemu_dir, delete=False) as stream:
            dump = Path(stream.name)
        dump.unlink()
        try:
            await self.monitor.hmp(f"pmemsave {self.address:#x} {self.memory_bytes} {dump.name}")
            return decode(dump.read_bytes(), self.columns, None)
        finally:
            dump.unlink(missing_ok=True)

    async def wait(self, predicate: Callable[[str], bool], timeout: float | None) -> str:
        """Poll VGA text until a predicate matches or the timeout expires.

        When invalidated, at least one screen change must be observed before a
        predicate may match. This prevents fast installer responses from being
        sent twice against stale text.
        """

        text = await self._fresh_screen()
        if timeout is None:
            return await self._wait_for_predicate(predicate, text)
        async with asyncio.timeout(timeout):
            return await self._wait_for_predicate(predicate, text)

    async def _fresh_screen(self) -> str:
        """Wait past any invalidated VGA snapshot and return fresh text."""
        while True:
            text = await self._read_screen()
            if self._stale is None or text != self._stale:
                self._stale = None
                return text
            await asyncio.sleep(min(self.interval, 0.01))

    async def _read_screen(self) -> str:
        """Read VGA text and append changes to screen history."""
        text = await self._read()
        if text != self.current:
            self.history.append(Screen(monotonic(), text))
        return text

    async def _wait_for_predicate(self, predicate: Callable[[str], bool], text: str) -> str:
        """Poll fresh VGA screens until the caller's predicate matches."""
        while not predicate(text):
            await asyncio.sleep(self.interval)
            text = await self._read_screen()
        return text
