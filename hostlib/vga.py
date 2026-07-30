"""Observe VGA text screens by reading guest memory through QMP.

The observer is demand-driven: each wait dumps VGA memory with ``pmemsave`` and
decodes character bytes. Invalidation prevents a prompt that was just answered
from matching again before the guest redraws.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass
from enum import IntEnum
import logging
from pathlib import Path
import tempfile
from time import monotonic
from typing import Callable

from .qmp import Monitor

log = logging.getLogger(__name__)


class VgaColor(IntEnum):
    """Name the 16 colors encoded in a VGA text foreground attribute."""

    BLACK = 0
    BLUE = 1
    GREEN = 2
    CYAN = 3
    RED = 4
    MAGENTA = 5
    BROWN = 6
    LIGHT_GRAY = 7
    DARK_GRAY = 8
    LIGHT_BLUE = 9
    LIGHT_GREEN = 10
    LIGHT_CYAN = 11
    LIGHT_RED = 12
    LIGHT_MAGENTA = 13
    YELLOW = 14
    WHITE = 15


@dataclass(frozen=True, slots=True)
class ScreenSnapshot:
    """Retain raw VGA rows for character- and attribute-aware comparisons."""

    columns: int
    contents: tuple[bytes, ...]

    @classmethod
    def capture(cls, memory: bytes, columns: int = 80, rows: int | None = 25) -> ScreenSnapshot:
        """Capture rows of interleaved VGA character and attribute bytes."""
        if columns <= 0:
            raise ValueError("columns must be greater than zero")
        if rows is not None and rows <= 0:
            raise ValueError("rows must be greater than zero")
        if len(memory) % 2:
            raise ValueError("VGA memory must contain complete character/attribute pairs")
        length = len(memory) if rows is None else min(len(memory), columns * rows * 2)
        width = columns * 2
        contents = tuple(
            row + b" \x07" * ((width - len(row)) // 2)
            for index in range(0, length, width)
            if (row := memory[index : index + width])
        )
        return cls(columns, contents)

    def cell(self, row: int, column: int) -> VgaCell:
        """Return one decoded, one-based VGA cell."""
        if row < 1 or column < 1 or row > len(self.contents) or column > self.columns:
            raise ValueError(f"cell ({row}, {column}) is outside this snapshot")
        try:
            contents = self.contents[row - 1]
            offset = (column - 1) * 2
            character = bytes((contents[offset],)).decode("cp437")
            return VgaCell(
                row,
                column,
                character if character.isprintable() else " ",
                contents[offset + 1],
            )
        except (IndexError, ValueError) as exc:
            raise ValueError(f"cell ({row}, {column}) is outside this snapshot") from exc

    def view(self, bounds: ScreenBounds) -> ScreenView:
        """Return a decoded rectangular view with absolute cell coordinates."""
        screen = ScreenBounds(1, 1, len(self.contents), self.columns)
        if bounds.width <= 0 or bounds.bottom < bounds.top or not screen.contains(bounds):
            raise ValueError(f"view {bounds} is outside this snapshot")
        start = (bounds.left - 1) * 2
        stop = bounds.right * 2
        lines = tuple(
            _decode_row(contents[start:stop])
            for contents in self.contents[bounds.top - 1 : bounds.bottom]
        )
        cells = tuple(
            self.cell(row, column)
            for row in range(bounds.top, bounds.bottom + 1)
            for column in range(bounds.left, bounds.right + 1)
        )
        return ScreenView(bounds, lines, cells)

    @property
    def text(self) -> str:
        """Decode every captured cell without constructing a selection."""
        return "\n".join(_decode_row(row) for row in self.contents)


@dataclass(frozen=True, slots=True)
class ScreenBounds:
    """Describe an inclusive, one-based rectangle in VGA text memory."""

    top: int
    left: int
    bottom: int
    right: int

    @property
    def width(self) -> int:
        """Return the rectangle width in character cells."""
        return self.right - self.left + 1

    def contains(self, other: ScreenBounds) -> bool:
        """Return whether another rectangle lies entirely within this one."""
        return (
            self.top <= other.top
            and self.left <= other.left
            and self.bottom >= other.bottom
            and self.right >= other.right
        )


@dataclass(frozen=True, slots=True)
class VgaCell:
    """Retain a decoded character, attribute, and one-based screen location."""

    row: int
    column: int
    character: str
    attribute: int

    @property
    def foreground(self) -> VgaColor:
        """Return the cell's foreground color."""
        return VgaColor(self.attribute & 0x0F)

    @property
    def background(self) -> VgaColor:
        """Return the cell's background color, treating bit 7 as blink."""
        return VgaColor((self.attribute >> 4) & 0x07)


@dataclass(frozen=True, slots=True)
class ScreenView:
    """Expose only one rectangular part of a VGA snapshot."""

    bounds: ScreenBounds
    lines: tuple[str, ...]
    cells: tuple[VgaCell, ...]

    def cell(self, row: int, column: int) -> VgaCell:
        """Return one decoded cell within the view."""
        if not (
            self.bounds.top <= row <= self.bounds.bottom
            and self.bounds.left <= column <= self.bounds.right
        ):
            raise ValueError(f"cell ({row}, {column}) is outside this view")
        offset = (row - self.bounds.top) * self.bounds.width + column - self.bounds.left
        return self.cells[offset]


def _decode_row(memory: bytes) -> str:
    """Decode one row of VGA character/attribute pairs."""
    characters = memory[0::2].decode("cp437")
    return "".join(character if character.isprintable() else " " for character in characters)


class ScreenObserver:
    """Read VGA memory on demand while a caller waits for a screen predicate."""

    _address = 0xB8000
    _memory_bytes = 32768
    _columns = 80

    def __init__(
        self,
        monitor: Monitor,
        qemu_dir: Path,
        *,
        interval: float = 0.25,
    ) -> None:
        """Initialize VGA polling for one VM."""
        self.monitor = monitor
        self.qemu_dir = qemu_dir
        self.interval = interval
        self._current = ""
        self._stale: str | None = None

    def invalidate(self) -> None:
        """Require the next wait to observe a screen change before matching."""
        self._stale = self._current

    async def capture(self, rows: int | None = None) -> ScreenSnapshot:
        """Dump VGA memory and return a raw screen snapshot."""
        if rows is not None and rows <= 0:
            raise ValueError("rows must be greater than zero")
        started = monotonic()
        memory_bytes = (
            self._memory_bytes
            if rows is None
            else min(self._memory_bytes, self._columns * rows * 2)
        )
        with tempfile.NamedTemporaryFile(dir=self.qemu_dir, delete=False) as stream:
            dump = Path(stream.name)
        dump.unlink()
        try:
            await self.monitor.hmp(f"pmemsave {self._address:#x} {memory_bytes} {dump.name}")
            return ScreenSnapshot.capture(dump.read_bytes(), self._columns, rows)
        finally:
            dump.unlink(missing_ok=True)
            log.debug("VGA capture completed in %.3fs", monotonic() - started)

    async def wait(self, predicate: Callable[[str], bool], timeout: float | None) -> str:
        """Poll VGA text until a predicate matches or the timeout expires.

        When invalidated, at least one screen change must be observed before a
        predicate may match. This prevents fast installer responses from being
        sent twice against stale text.
        """
        snapshot = await self.wait_snapshot(lambda frame: predicate(frame.text), timeout)
        return snapshot.text

    async def wait_snapshot(
        self,
        predicate: Callable[[ScreenSnapshot], bool],
        timeout: float | None,
        *,
        rows: int | None = None,
        interval: float | None = None,
    ) -> ScreenSnapshot:
        """Poll snapshots immediately, backing off only during longer waits."""
        started = monotonic()
        captures = 1
        slept = 0.0
        poll_interval = 0.01 if interval is None else interval
        max_interval = self.interval if interval is None else interval

        while True:
            snapshot = await self.capture(rows)
            prior = (
                self._stale if rows is None else "\n".join((self._stale or "").splitlines()[:rows])
            )
            if self._stale is None or snapshot.text != prior:
                self._stale = None
                if rows is None:
                    self._current = snapshot.text
                break
            await asyncio.sleep(min(self.interval, 0.01))

        async def next_snapshot() -> ScreenSnapshot:
            """Capture the next frame after the current adaptive delay."""
            nonlocal captures, poll_interval, slept
            if poll_interval:
                await asyncio.sleep(poll_interval)
                slept += poll_interval
            snapshot = await self.capture(rows)
            if rows is None:
                self._current = snapshot.text
            captures += 1
            if interval is None:
                poll_interval = min(max_interval, poll_interval * 2)
            return snapshot

        try:
            async with asyncio.timeout(timeout):
                while not predicate(snapshot):
                    snapshot = await next_snapshot()
                return snapshot
        finally:
            log.debug(
                "VGA snapshot wait finished in %.3fs: captures=%d artificial_sleep=%.3fs timeout=%s",
                monotonic() - started,
                captures,
                slept,
                timeout,
            )
