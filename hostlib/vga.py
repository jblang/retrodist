"""Observe VGA text screens by reading guest memory through QMP.

The observer is demand-driven: each wait dumps VGA memory with ``pmemsave``,
decodes character bytes, and records changed screens. Invalidation prevents a
prompt that was just answered from matching again before the guest redraws.
"""

from __future__ import annotations

import asyncio
from collections import deque
from dataclasses import dataclass
from enum import IntEnum
import logging
from pathlib import Path
import re
import tempfile
from time import monotonic
from typing import Callable, Iterable

from .qmp import Monitor

log = logging.getLogger(__name__)

_COLOR_ALIASES = {
    "grey": "light-gray",
    "light-grey": "light-gray",
    "dark-grey": "dark-gray",
    "purple": "magenta",
    "light-purple": "light-magenta",
}


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

    @classmethod
    def parse(cls, value: str) -> VgaColor:
        """Parse a symbolic VGA color name, including common aliases."""
        name = value.lower().replace("_", "-")
        name = _COLOR_ALIASES.get(name, name)
        try:
            return cls[name.upper().replace("-", "_")]
        except KeyError as exc:
            raise ValueError(f"unknown VGA color {value!r}") from exc

    @classmethod
    def names(cls) -> tuple[str, ...]:
        """Return the accepted canonical symbolic names."""
        return tuple(color.symbolic_name for color in cls)

    @property
    def symbolic_name(self) -> str:
        """Return the canonical command-line spelling of the color."""
        return self.name.lower().replace("_", "-")

    @property
    def is_background(self) -> bool:
        """Return whether the color fits the classic three-bit background field."""
        return self <= self.LIGHT_GRAY


@dataclass(frozen=True, slots=True)
class AttributeFilter:
    """Select VGA cells by colors, treating attribute bit 7 as blink."""

    foreground: frozenset[VgaColor] | None = None
    background: frozenset[VgaColor] | None = None
    color_pairs: frozenset[tuple[VgaColor, VgaColor]] | None = None

    def __post_init__(self) -> None:
        """Reject colors that cannot occur in classic VGA background bits."""
        invalid = {color for color in self.background or () if not color.is_background}
        invalid.update(
            background for _, background in self.color_pairs or () if not background.is_background
        )
        if invalid:
            names = ", ".join(sorted(color.symbolic_name for color in invalid))
            raise ValueError(
                f"bright VGA colors cannot be used as backgrounds: {names}; "
                "bit 7 is treated as blink"
            )

    def matches(self, attribute: int) -> bool:
        """Return whether a VGA attribute byte satisfies every configured filter."""
        foreground = VgaColor(attribute & 0x0F)
        background = VgaColor((attribute >> 4) & 0x07)
        return (
            (self.foreground is None or foreground in self.foreground)
            and (self.background is None or background in self.background)
            and (self.color_pairs is None or (foreground, background) in self.color_pairs)
        )

    def matches_row(self, memory: bytes) -> bool:
        """Return whether any cell in a raw VGA row matches this filter."""
        return any(self.matches(attribute) for attribute in memory[1::2])

    @property
    def is_active(self) -> bool:
        """Return whether any attribute constraint limits visible cells."""
        return any(
            value is not None for value in (self.foreground, self.background, self.color_pairs)
        )


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
        contents = tuple(memory[index : index + width] for index in range(0, length, width))
        return cls(columns, contents)

    def select(self, *attributes: AttributeFilter) -> AttributeSelection:
        """Select cells matching any supplied filter, or every cell if omitted."""
        filters = attributes or (AttributeFilter(),)
        cells = tuple(
            VgaCell.from_bytes(row, column, character, attribute)
            for row, contents in enumerate(self.contents, 1)
            for column, (character, attribute) in enumerate(zip(contents[0::2], contents[1::2]), 1)
            if any(candidate.matches(attribute) for candidate in filters)
        )
        return AttributeSelection(self, filters, cells)

    def limit(self, rows: int | None) -> ScreenSnapshot:
        """Return a view restricted to the first rows, or this snapshot for all."""
        if rows is None:
            return self
        if rows <= 0:
            raise ValueError("rows must be greater than zero")
        return ScreenSnapshot(self.columns, self.contents[:rows])

    def cell(self, row: int, column: int) -> VgaCell:
        """Return one decoded, one-based VGA cell."""
        if row < 1 or column < 1 or row > len(self.contents) or column > self.columns:
            raise ValueError(f"cell ({row}, {column}) is outside this snapshot")
        try:
            contents = self.contents[row - 1]
            offset = (column - 1) * 2
            return VgaCell.from_bytes(row, column, contents[offset], contents[offset + 1])
        except (IndexError, ValueError) as exc:
            raise ValueError(f"cell ({row}, {column}) is outside this snapshot") from exc

    def view(self, bounds: ScreenBounds) -> ScreenView:
        """Return a decoded rectangular view with absolute cell coordinates."""
        screen = ScreenBounds(1, 1, len(self.contents), self.columns)
        if bounds.width <= 0 or bounds.height <= 0 or not screen.contains(bounds):
            raise ValueError(f"view {bounds} is outside this snapshot")
        start = (bounds.left - 1) * 2
        stop = bounds.right * 2
        lines = tuple(
            _decode_row(contents[start:stop], None, None)
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
        return "\n".join(_decode_row(row, None, None) for row in self.contents)


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

    @property
    def height(self) -> int:
        """Return the rectangle height in character cells."""
        return self.bottom - self.top + 1

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

    @classmethod
    def from_bytes(cls, row: int, column: int, character: int, attribute: int) -> VgaCell:
        """Decode one character/attribute pair from VGA text memory."""
        decoded = bytes((character,)).decode("cp437")
        return cls(row, column, decoded if decoded.isprintable() else " ", attribute)

    @property
    def foreground(self) -> VgaColor:
        """Return the cell's foreground color."""
        return VgaColor(self.attribute & 0x0F)

    @property
    def background(self) -> VgaColor:
        """Return the cell's background color, treating bit 7 as blink."""
        return VgaColor((self.attribute >> 4) & 0x07)

    @property
    def blink(self) -> bool:
        """Return whether VGA attribute bit 7 is set."""
        return bool(self.attribute & 0x80)

    @property
    def bounds(self) -> ScreenBounds:
        """Return the one-cell rectangle occupied by this cell."""
        return ScreenBounds(self.row, self.column, self.row, self.column)


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


def _bounds(cells: Iterable[VgaCell]) -> ScreenBounds | None:
    """Return the smallest rectangle containing a collection of cells."""
    materialized = tuple(cells)
    if not materialized:
        return None
    return ScreenBounds(
        min(cell.row for cell in materialized),
        min(cell.column for cell in materialized),
        max(cell.row for cell in materialized),
        max(cell.column for cell in materialized),
    )


def _render(cells: Iterable[VgaCell], bounds: ScreenBounds) -> str:
    """Render selected cells within a rectangle, preserving unmatched positions."""
    selected = {(cell.row, cell.column): cell.character for cell in cells}
    return "\n".join(
        "".join(
            selected.get((row, column), " ") for column in range(bounds.left, bounds.right + 1)
        )
        for row in range(bounds.top, bounds.bottom + 1)
    )


@dataclass(frozen=True, slots=True)
class TextLocation:
    """Locate selected text within one VGA screen row."""

    text: str
    bounds: ScreenBounds

    @property
    def row(self) -> int:
        """Return the one-based row containing the text."""
        return self.bounds.top

    @property
    def column(self) -> int:
        """Return the one-based starting column of the text."""
        return self.bounds.left


@dataclass(frozen=True, slots=True)
class ScreenRegion:
    """Represent one orthogonally connected group of selected VGA cells."""

    cells: tuple[VgaCell, ...]

    @property
    def bounds(self) -> ScreenBounds:
        """Return the smallest rectangle containing the region."""
        bounds = _bounds(self.cells)
        assert bounds is not None
        return bounds

    @property
    def text(self) -> str:
        """Render the region inside its bounds, including matching blank cells."""
        return _render(self.cells, self.bounds)


@dataclass(frozen=True, slots=True)
class AttributeSelection:
    """Expose text, locations, and regions selected by one or more filters.

    Filters are combined as a union: a cell is selected when any filter
    matches. Constraints within one :class:`AttributeFilter` remain
    conjunctive.
    """

    snapshot: ScreenSnapshot
    filters: tuple[AttributeFilter, ...]
    cells: tuple[VgaCell, ...]

    @property
    def bounds(self) -> ScreenBounds | None:
        """Return the smallest rectangle containing every selected cell."""
        return _bounds(self.cells)

    @property
    def rows(self) -> tuple[DecodedRow, ...]:
        """Render rows containing selected attributes at original columns."""
        by_row: dict[int, list[VgaCell]] = {}
        for cell in self.cells:
            by_row.setdefault(cell.row, []).append(cell)
        return tuple(
            DecodedRow(
                row,
                _render(cells, ScreenBounds(row, 1, row, self.snapshot.columns)),
            )
            for row, cells in sorted(by_row.items())
        )

    @property
    def text(self) -> str:
        """Join rows containing selected attributes for plain-text matching."""
        return "\n".join(row.text for row in self.rows)

    def find(self, text: str) -> tuple[TextLocation, ...]:
        """Find literal text in selected cells and return its screen locations."""
        if not text or "\n" in text:
            raise ValueError("text must be a non-empty single-line string")
        locations = []
        selected = {(cell.row, cell.column) for cell in self.cells}
        for row in self.rows:
            start = 0
            while (start := row.text.find(text, start)) >= 0:
                columns = range(start + 1, start + len(text) + 1)
                if all((row.number, column) in selected for column in columns):
                    locations.append(
                        TextLocation(
                            text,
                            ScreenBounds(
                                row.number,
                                start + 1,
                                row.number,
                                start + len(text),
                            ),
                        )
                    )
                start += 1
        return tuple(locations)

    @property
    def regions(self) -> tuple[ScreenRegion, ...]:
        """Return orthogonally connected selected-cell regions in screen order."""
        remaining = {(cell.row, cell.column): cell for cell in self.cells}
        regions = []
        while remaining:
            origin = min(remaining)
            pending = [origin]
            connected = []
            while pending:
                position = pending.pop()
                cell = remaining.pop(position, None)
                if cell is None:
                    continue
                connected.append(cell)
                row, column = position
                pending.extend(
                    (
                        (row - 1, column),
                        (row, column - 1),
                        (row, column + 1),
                        (row + 1, column),
                    )
                )
            regions.append(
                ScreenRegion(tuple(sorted(connected, key=lambda cell: (cell.row, cell.column))))
            )
        return tuple(regions)

    def regions_containing(self, bounds: ScreenBounds) -> tuple[ScreenRegion, ...]:
        """Return connected regions whose bounding rectangles contain a target."""
        return tuple(region for region in self.regions if region.bounds.contains(bounds))


@dataclass(frozen=True, slots=True)
class DecodedRow:
    """Represent one decoded row at its original one-based screen position."""

    number: int
    text: str


@dataclass(frozen=True, slots=True)
class DecodedScreen:
    """Return decoded rows together with the raw snapshot that produced them."""

    rows: tuple[DecodedRow, ...]
    snapshot: ScreenSnapshot

    @property
    def text(self) -> str:
        """Join the selected rows for plain-text consumers."""
        return "\n".join(row.text for row in self.rows)


def _as_colors(values: frozenset[int] | None) -> frozenset[VgaColor] | None:
    """Convert optional numeric color values for the plain-text compatibility API."""
    return frozenset(map(VgaColor, values)) if values is not None else None


def _as_color_pairs(
    values: frozenset[tuple[int, int]] | None,
) -> frozenset[tuple[VgaColor, VgaColor]] | None:
    """Convert optional numeric pairs for the plain-text compatibility API."""
    return (
        frozenset(
            (VgaColor(foreground), VgaColor(background)) for foreground, background in values
        )
        if values is not None
        else None
    )


def _decode_row(
    memory: bytes,
    attributes: AttributeFilter | None,
    previous: bytes | None,
) -> str:
    """Decode one VGA row, masking cells unchanged from the prior row."""
    characters = memory[0::2].decode("cp437")
    attribute_bytes = memory[1::2]
    return "".join(
        (
            character
            if (
                character.isprintable()
                and (attributes is None or attributes.matches(attribute))
                and (
                    previous is None
                    or memory[index * 2 : index * 2 + 2] != previous[index * 2 : index * 2 + 2]
                )
            )
            else " "
        )
        for index, (character, attribute) in enumerate(zip(characters, attribute_bytes))
    )


def decode_screen(
    memory: bytes,
    columns: int = 80,
    rows: int | None = 25,
    *,
    attributes: AttributeFilter | None = None,
    skip_blank: bool = False,
    trim_whitespace: bool = False,
    changed_from: ScreenSnapshot | None = None,
) -> DecodedScreen:
    """Decode and select VGA rows while preserving their original positions.

    CP437 graphical bytes become Unicode. Non-printable, attribute-filtered,
    or unchanged cells become spaces. Active attribute filters omit only rows
    with no matching attributes, even when the matching cells render as spaces.
    ``skip_blank`` omits blank rows only for unfiltered dumps.
    ``trim_whitespace`` strips selected lines after filtering and masking.
    ``changed_from`` compares raw character and attribute bytes, and an
    incompatible snapshot causes every row to be returned in full.
    """
    snapshot = ScreenSnapshot.capture(memory, columns, rows)
    previous = (
        changed_from.contents
        if changed_from is not None and changed_from.columns == columns
        else None
    )
    selected = []
    for index, current in enumerate(snapshot.contents):
        prior = previous[index] if previous is not None and index < len(previous) else None
        if prior is not None and current == prior:
            continue
        line = _decode_row(current, attributes, prior)
        if attributes is not None and attributes.is_active:
            if not attributes.matches_row(current):
                continue
        elif skip_blank and not line.strip():
            continue
        if trim_whitespace:
            line = line.strip()
        selected.append(DecodedRow(index + 1, line))
    return DecodedScreen(tuple(selected), snapshot)


def decode(
    memory: bytes,
    columns: int = 80,
    rows: int | None = 25,
    *,
    foreground: frozenset[int] | None = None,
    background: frozenset[int] | None = None,
    color_pairs: frozenset[tuple[int, int]] | None = None,
) -> str:
    """Decode interleaved VGA character/attribute bytes into plain text.

    This compatibility wrapper returns text only. Use :func:`decode_screen` for
    symbolic colors, row positions, blank-row removal, snapshots, and change
    detection.
    """
    attributes = AttributeFilter(
        foreground=_as_colors(foreground),
        background=_as_colors(background),
        color_pairs=_as_color_pairs(color_pairs),
    )
    return decode_screen(
        memory,
        columns,
        rows,
        attributes=attributes,
    ).text


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
        rows: int | None = None,
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

    async def capture(self, rows: int | None = None) -> ScreenSnapshot:
        """Dump VGA memory and return a queryable raw screen snapshot.

        ``rows=None`` captures the complete configured memory range. With the
        default geometry this is 32 KiB interpreted as 80-column text rows.
        """
        if rows is not None and rows <= 0:
            raise ValueError("rows must be greater than zero")
        started = monotonic()
        memory_bytes = (
            self.memory_bytes if rows is None else min(self.memory_bytes, self.columns * rows * 2)
        )
        with tempfile.NamedTemporaryFile(dir=self.qemu_dir, delete=False) as stream:
            dump = Path(stream.name)
        dump.unlink()
        try:
            await self.monitor.hmp(f"pmemsave {self.address:#x} {memory_bytes} {dump.name}")
            return ScreenSnapshot.capture(dump.read_bytes(), self.columns, rows)
        finally:
            dump.unlink(missing_ok=True)
            log.debug("VGA capture completed in %.3fs", monotonic() - started)

    async def select(
        self,
        *attributes: AttributeFilter,
        rows: int | None = None,
    ) -> AttributeSelection:
        """Capture memory rows and select cells matching any supplied filter."""
        snapshot = await self.capture()
        return snapshot.limit(self.rows if rows is None else rows).select(*attributes)

    async def _read(self) -> str:
        """Dump and decode the configured VGA text-memory range."""
        return (await self.capture()).text

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

    async def wait_selection(
        self,
        predicate: Callable[[AttributeSelection], bool],
        *attributes: AttributeFilter,
        timeout: float | None,
        rows: int | None = None,
    ) -> AttributeSelection:
        """Poll queryable VGA selections until a predicate matches.

        Multiple filters form a union. Full, unfiltered text is used for screen
        history and invalidation so a selected region cannot appear fresh merely
        because a different view was requested after pressing Enter.
        """
        selected_rows = self.rows if rows is None else rows
        selection = await self._fresh_selection(attributes, selected_rows)
        if timeout is None:
            return await self._wait_for_selection(predicate, selection, attributes, selected_rows)
        async with asyncio.timeout(timeout):
            return await self._wait_for_selection(predicate, selection, attributes, selected_rows)

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
        if rows is None:
            snapshot = (await self._fresh_selection((), self.rows)).snapshot
        else:
            while True:
                snapshot = await self.capture(rows)
                prior = "\n".join((self._stale or "").splitlines()[:rows])
                if self._stale is None or snapshot.text != prior:
                    self._stale = None
                    break
                await asyncio.sleep(min(self.interval, 0.01))

        async def next_snapshot() -> ScreenSnapshot:
            """Capture the next frame after the current adaptive delay."""
            nonlocal captures, poll_interval, slept
            if poll_interval:
                await asyncio.sleep(poll_interval)
                slept += poll_interval
            if rows is None:
                snapshot = (await self._selected_screen((), self.rows))[1].snapshot
            else:
                snapshot = await self.capture(rows)
            captures += 1
            if interval is None:
                poll_interval = min(max_interval, poll_interval * 2)
            return snapshot

        try:
            if timeout is None:
                while not predicate(snapshot):
                    snapshot = await next_snapshot()
                return snapshot
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

    async def _selected_screen(
        self,
        attributes: tuple[AttributeFilter, ...],
        rows: int | None,
    ) -> tuple[str, AttributeSelection]:
        """Capture once and return both the full screen and requested selection."""
        snapshot = await self.capture()
        full = snapshot.text
        if full != self.current:
            self.history.append(Screen(monotonic(), full))
        return full, snapshot.limit(rows).select(*attributes)

    async def _fresh_selection(
        self,
        attributes: tuple[AttributeFilter, ...],
        rows: int | None,
    ) -> AttributeSelection:
        """Wait past an invalidated full screen and return its selected view."""
        while True:
            full, selection = await self._selected_screen(attributes, rows)
            if self._stale is None or full != self._stale:
                self._stale = None
                return selection
            await asyncio.sleep(min(self.interval, 0.01))

    async def _wait_for_selection(
        self,
        predicate: Callable[[AttributeSelection], bool],
        selection: AttributeSelection,
        attributes: tuple[AttributeFilter, ...],
        rows: int | None,
    ) -> AttributeSelection:
        """Poll fresh selections until the caller's predicate matches."""
        while not predicate(selection):
            await asyncio.sleep(self.interval)
            _, selection = await self._selected_screen(attributes, rows)
        return selection

    async def _wait_for_predicate(self, predicate: Callable[[str], bool], text: str) -> str:
        """Poll fresh VGA screens until the caller's predicate matches."""
        while not predicate(text):
            await asyncio.sleep(self.interval)
            text = await self._read_screen()
        return text
