"""Recognize and drive the small set of Red Hat C-installer screen dialogs.

This intentionally lives above :mod:`hostlib.vga`: VGA exposes cells and
snapshots, while this module knows the old installer palette and widgets.
"""

from __future__ import annotations

from dataclasses import dataclass
from itertools import groupby
import logging
import re

from .session import InstallSession
from .vga import ScreenBounds, ScreenSnapshot, ScreenView, VgaCell, VgaColor

log = logging.getLogger(__name__)


def _label(value: str) -> str:
    """Normalize a rendered item label for exact logical matching."""
    return " ".join(value.split()).casefold()


@dataclass(frozen=True, slots=True)
class DialogState:
    """The controls needed by one supported Red Hat installer dialog."""

    title: str
    view: ScreenView
    active_item: str | None
    visible_items: tuple[str, ...]
    checked: dict[str, bool]
    focused_checkbox: str | None
    selected_radios: dict[str, bool]
    focused_radio: str | None


class NewtDialog:
    """Parse and navigate menus and checklists used by Red Hat C installers."""

    _title = re.compile(r"┤\s*(.*?)\s*├")
    _button = re.compile(r"┌─+┐")
    _checklist = re.compile(r"\[([ *])\]\s*(.*?)\s*$")
    _radio = re.compile(r"\(([ *])\)\s*(.*?)\s*$")
    _limit = 100
    _transition_timeout = 0.25
    _transition_interval = 0.0

    def __init__(self, session: InstallSession) -> None:
        """Bind one synchronous installer session."""
        self.s = session
        self._current: DialogState | None = None

    def wait_for_title(self, title: str) -> DialogState:
        """Wait specifically for a delimiter-bounded dialog title."""
        log.info("⏳ dialog %s", title)
        target = _label(title)
        snapshot = self.s.vga_wait_snapshot(
            lambda frame: any(_label(found) == target for found, _ in self._dialogs(frame))
        )
        state = self.parse(snapshot, title=title)
        self._current = state
        log.info("🖥️  dialog %s", state.title)
        return state

    def press_button(self, label: str) -> None:
        """Focus the named rendered button and activate it with Enter."""
        self._activate_button(label, "ret", "press button")

    def advance(self, label: str) -> None:
        """Advance with F12 where the caller source defines that action."""
        self._activate_button(label, "f12", "advance")

    def _activate_button(self, label: str, key: str, action: str) -> None:
        """Focus a rendered button, then use one source-authorized activation key."""
        target = _label(label)
        state = self.capture()
        for _ in range(self._limit):
            buttons = self._button_states(state)
            selected = next((name for name, focused in buttons.items() if focused), None)
            if target not in buttons:
                raise RuntimeError(f"Dialog {state.title!r} has no button {label!r}")
            if selected == target or (key == "f12" and selected is None):
                log.info("👇 dialog %s: %s %s", state.title, action, label)
                self._press(key)
                return
            previous_checkbox = state.focused_checkbox
            previous_radio = state.focused_radio
            self._press("tab")
            state = self._wait_for_state(
                lambda current: self._selected_button(current) != selected
                or current.focused_checkbox != previous_checkbox
                or current.focused_radio != previous_radio
            )
        raise RuntimeError(f"Dialog {state.title!r} never focused button {label!r}")

    def capture(self) -> DialogState:
        """Capture and parse through the current dialog's bottom row."""
        rows = self._current.view.bounds.bottom if self._current is not None else None
        return self._parse_current(self.s.vga_screen(rows))

    def enter_text(
        self,
        value: str,
        *,
        field: str,
        sensitive: bool = False,
    ) -> None:
        """Type one focused dialog entry value and submit that entry."""
        state = self.capture()
        rendered = "<redacted>" if sensitive else repr(value)
        log.info("⌨️  dialog %s: enter %s=%s", state.title, field, rendered)
        self.s.kb_type_quiet(f"{value}\n")

    def replace_text(self, value: str, *, field: str) -> None:
        """Clear a focused Newt entry with Ctrl-A/Ctrl-K, then submit a value."""
        state = self.capture()
        log.info("⌨️  dialog %s: set %s=%r", state.title, field, value)
        self._press("ctrl-a")
        self._press("ctrl-k")
        self.s.kb_type_quiet(f"{value}\n")

    @classmethod
    def parse(cls, snapshot: ScreenSnapshot, *, title: str | None = None) -> DialogState:
        """Parse a named dialog, or the geometrically innermost visible dialog."""
        dialogs = cls._dialogs(snapshot)
        if title is not None:
            dialogs = tuple(dialog for dialog in dialogs if _label(dialog[0]) == _label(title))
        if not dialogs:
            raise RuntimeError("Screen does not contain a Red Hat dialog title")
        title, bounds = max(
            dialogs,
            key=lambda candidate: sum(
                other[1] != candidate[1] and other[1].contains(candidate[1]) for other in dialogs
            ),
        )
        view = snapshot.view(bounds)
        active, visible_items = cls._menu(view)
        checklist, focused = cls._marked_items(view, cls._checklist)
        radios, focused_radio = cls._marked_items(view, cls._radio)
        return DialogState(
            title,
            view,
            active,
            visible_items,
            {_label(name): checked for name, checked in checklist},
            focused,
            {_label(name): selected for name, selected in radios},
            focused_radio,
        )

    @classmethod
    def _dialogs(cls, snapshot: ScreenSnapshot) -> tuple[tuple[str, ScreenBounds], ...]:
        """Return every titled dialog paired with its enclosing border."""
        dialogs = []
        for row, text in enumerate(snapshot.text.splitlines(), 1):
            for match in cls._title.finditer(text):
                bounds = cls._bounds(snapshot, row, match.start() + 1)
                if bounds is not None:
                    dialogs.append((match.group(1), bounds))
        return tuple(dialogs)

    @staticmethod
    def _bounds(
        snapshot: ScreenSnapshot,
        title_row: int,
        title_column: int,
    ) -> ScreenBounds | None:
        """Trace the connected box border containing one title delimiter."""
        line = snapshot.view(ScreenBounds(title_row, 1, title_row, snapshot.columns)).lines[0]
        left_delimiter = title_column - 1
        right_delimiter = line.find("├", left_delimiter + 1)
        if right_delimiter < 0:
            return None

        left = left_delimiter - 1
        while left >= 0 and line[left] == "─":
            left -= 1
        right = right_delimiter + 1
        while right < len(line) and line[right] == "─":
            right += 1
        if left < 0 or right >= len(line) or line[left] != "┌" or line[right] != "┐":
            return None

        for bottom in range(title_row + 1, len(snapshot.contents) + 1):
            left_edge = snapshot.cell(bottom, left + 1).character
            right_edge = snapshot.cell(bottom, right + 1).character
            if (left_edge, right_edge) == ("└", "┘"):
                base = snapshot.view(ScreenBounds(bottom, left + 1, bottom, right + 1)).lines[0]
                if base == f"└{'─' * (right - left - 1)}┘":
                    return ScreenBounds(title_row, left + 1, bottom, right + 1)
                return None
            if (left_edge, right_edge) != ("│", "│"):
                return None
        return None

    @classmethod
    def _menu(cls, view: ScreenView) -> tuple[str | None, tuple[str, ...]]:
        """Return the active list item and the rows in its visible list page."""
        bounds = view.bounds
        lines = view.lines
        highlighted: dict[int, list[tuple[int, str]]] = {}
        for cell in view.cells:
            if (
                bounds.top < cell.row < bounds.bottom
                and bounds.left < cell.column < bounds.right
                and not cls._radio.search(lines[cell.row - bounds.top].strip())
                and not cls._checklist.search(lines[cell.row - bounds.top].strip())
                and cell.foreground is VgaColor.YELLOW
                and cell.background is VgaColor.BLUE
            ):
                highlighted.setdefault(cell.row, []).append((cell.column, cell.character))
        if not highlighted:
            return None, ()

        active_row = min(highlighted)
        active_cells = highlighted[active_row]
        runs = (
            "".join(character for _, (_, character) in run)
            for _, run in groupby(enumerate(active_cells), lambda item: item[1][0] - item[0])
        )
        active = max(runs, key=len).split("#", 1)[0].split("▒", 1)[0].rstrip(" │")
        if not active:
            return None, ()

        scrollbar = cls._scrollbar(view.cells, bounds, active_row)
        scrollbar_column = scrollbar[0] if scrollbar is not None else None

        def menu_row(row: int) -> str | None:
            """Return one list row, excluding headings, buttons, and scrollbars."""
            right = scrollbar_column - 1 if scrollbar_column is not None else bounds.right - 1
            line = lines[row - bounds.top]
            text = line[1 : right - bounds.left + 1].strip()
            if not text:
                return None
            if cls._radio.search(text) or cls._checklist.search(text):
                return None
            return text

        if scrollbar is not None:
            _, top, bottom = scrollbar
        else:
            top = active_row
            while top > bounds.top + 1 and menu_row(top - 1) is not None:
                top -= 1
            bottom = active_row
            while bottom < bounds.bottom - 1 and menu_row(bottom + 1) is not None:
                bottom += 1
        visible = tuple(
            item for row in range(top, bottom + 1) if (item := menu_row(row)) is not None
        )
        return active, visible

    @staticmethod
    def _scrollbar(
        cells: tuple[VgaCell, ...], bounds: ScreenBounds, active_row: int
    ) -> tuple[int, int, int] | None:
        """Return the column and visible row range of the list's scrollbar."""
        columns: dict[int, set[int]] = {}
        for cell in cells:
            if (
                bounds.top < cell.row < bounds.bottom
                and bounds.left < cell.column < bounds.right
                and cell.character in {"#", "▒"}
            ):
                columns.setdefault(cell.column, set()).add(cell.row)
        candidates = (
            (column, min(rows), max(rows))
            for column, rows in columns.items()
            if len(rows) >= 2 and min(rows) <= active_row <= max(rows)
        )
        return max(candidates, key=lambda item: (item[2] - item[1], item[0]), default=None)

    @staticmethod
    def _marked_items(
        view: ScreenView, pattern: re.Pattern[str]
    ) -> tuple[tuple[tuple[str, bool], ...], str | None]:
        """Parse checkbox-like markers, using color only to identify focus."""
        entries: list[tuple[str, bool]] = []
        focused = None
        for offset, text in enumerate(view.lines[1:-1], 1):
            match = pattern.search(text.strip())
            if match is None:
                continue
            row = view.bounds.top + offset
            name = match.group(2).rstrip(" ▒#│")
            entries.append((name, match.group(1) == "*"))
            if any(
                (cell := view.cell(row, column)).foreground is VgaColor.BLUE
                and cell.background is VgaColor.BROWN
                for column in range(view.bounds.left, view.bounds.right + 1)
            ):
                focused = name
        return tuple(entries), focused

    def select_menu_item(self, label: str, *, label_width: int | None = None) -> None:
        """Find a menu item by visible pages, then align the active row to it."""
        target = _label(label)
        state = self.capture()
        page = lambda current: (current.active_item, current.visible_items)
        while state.focused_radio is not None or state.focused_checkbox is not None:
            self._press("tab")
            state = self.capture()
        log.info("📋 dialog %s: select menu %s", state.title, label)
        for direction in ("pgup", "pgdn"):
            for _ in range(self._limit):
                if self._focus_visible_menu_item(state, target, label_width):
                    return
                next_state = self._move(state, direction, page)
                if next_state is state:
                    break
                state = next_state
        raise RuntimeError(self._missing(label, state))

    def _focus_visible_menu_item(self, state: DialogState, target: str, width: int | None) -> bool:
        """Move within one visible menu page when it contains the target."""
        text = lambda item: item if width is None else item[:width].rstrip()
        visible = [_label(text(item)) for item in state.visible_items]
        if target not in visible:
            return False
        if visible.count(target) != 1:
            raise RuntimeError(
                f"Dialog {state.title!r} has duplicate visible menu matches for {target!r}"
            )
        active = _label(text(state.active_item or ""))
        if visible.count(active) != 1:
            raise RuntimeError(
                f"Dialog {state.title!r} could not locate active item "
                f"{state.active_item!r} in {state.visible_items!r}"
            )
        offset = visible.index(target) - visible.index(active)
        direction = "down" if offset > 0 else "up"
        for _ in range(abs(offset)):
            next_state = self._move(
                state,
                direction,
                lambda current: text(current.active_item or ""),
            )
            if next_state is state:
                raise RuntimeError(
                    f"Dialog {state.title!r} stopped before reaching visible item {target!r}"
                )
            state = next_state
        return True

    def set_radio(self, label: str) -> None:
        """Select one radio-list item, then move focus to the following control."""
        target = _label(label)
        state = self.capture()
        if target not in state.selected_radios:
            raise RuntimeError(f"Dialog {state.title!r} expected one radio {label!r}")
        log.info("🔘 dialog %s: select radio %s", state.title, label)
        for _ in range(self._limit):
            if state.focused_radio is not None:
                break
            self._press("tab")
            state = self._wait_for_state(lambda current: current.focused_radio is not None)
        else:
            raise RuntimeError(f"Dialog {state.title!r} never focused its radio list")

        state = self._seek(
            state,
            lambda current: current.focused_radio,
            lambda value: _label(value or "") == target,
            label,
            start="up",
        )

        if not state.selected_radios[target]:
            self._press("spc")
            state = self._wait_for_state(
                lambda current: current.selected_radios.get(target) is True
            )
            if not state.selected_radios.get(target):
                raise RuntimeError(f"Radio {label!r} did not become selected")

        self._press("tab")
        state = self._wait_for_state(lambda current: current.focused_radio is None)
        if state.focused_radio is not None:
            raise RuntimeError(f"Dialog {state.title!r} did not leave the radio list after Tab")

    def select_partition(self, device: str) -> None:
        """Select the source-rendered partition row whose first token is ``device``."""
        target = self._partition_device(device)
        state = self.capture()
        log.info("📋 dialog %s: select partition %s", state.title, device)
        self._seek(
            state,
            lambda current: current.active_item,
            lambda value: self._partition_device(value or "") == target,
            device,
        )

    @staticmethod
    def _partition_device(row: str) -> str:
        """Normalize the optional ``/dev/`` prefix on a partition row's device."""
        tokens = row.split()
        if not tokens:
            return ""
        device = tokens[0].casefold()
        return device.removeprefix("/dev/")

    def move_down(self) -> None:
        """Move the current control down once."""
        state = self.capture()
        log.info("📋 dialog %s: move focus down", state.title)
        self._press("down")
        self.capture()

    def check_partition(self, device: str) -> None:
        """Check the partition row whose source-rendered first token is ``device``."""
        target = self._partition_device(device)
        state = self.capture()
        log.info("☑️  dialog %s: check partition %s", state.title, device)
        state = self._seek(
            state,
            lambda current: current.focused_checkbox,
            lambda value: self._partition_device(value or "") == target,
            device,
        )
        focused = _label(state.focused_checkbox or "")
        self._set_checked(state, focused, True, device)

    def set_checkbox(self, label: str, checked: bool = True) -> None:
        """Set one visible standalone checkbox reached through form traversal."""
        target = _label(label)
        state = self.capture()
        if target not in state.checked:
            raise RuntimeError(f"Dialog {state.title!r} expected checkbox {label!r}")
        log.info("☑️  dialog %s: set checkbox %s=%s", state.title, label, checked)
        for _ in range(self._limit):
            if _label(state.focused_checkbox or "") == target:
                self._set_checked(state, target, checked, label)
                return
            self._press("tab")
            state = self._wait_for_state(
                lambda current: current.focused_checkbox != state.focused_checkbox
                or self._selected_button(current) != self._selected_button(state)
            )
        raise RuntimeError(f"Dialog {state.title!r} never focused checkbox {label!r}")

    def set_checklist_items(self, selected: list[str]) -> None:
        """Make the checklist exactly match the selected labels."""
        requested = {_label(label): label for label in selected}
        if len(requested) != len(selected):
            raise ValueError("Checklist choices contain duplicate normalized labels")
        pending = dict(requested)
        state = self._to_top(self.capture(), lambda item: item.focused_checkbox)
        log.info("☑️  dialog %s: apply %d checkbox selections", state.title, len(selected))
        for _ in range(self._limit):
            focus = _label(state.focused_checkbox or "")
            label = requested.get(focus, state.focused_checkbox or "")
            checked = focus in requested
            current = state.checked.get(focus)
            if current is None:
                raise RuntimeError(self._missing(label, state))
            if current != checked:
                log.info("☑️  dialog %s: set %s=%s", state.title, label, checked)
                state = self._set_checked(state, focus, checked, label)
            pending.pop(focus, None)
            next_state = self._move(state, "down", lambda item: item.focused_checkbox)
            if next_state is state:
                if not pending:
                    return
                break
            state = next_state
        label = next(iter(pending.values()))
        raise RuntimeError(self._missing(label, state))

    def _set_checked(self, state: DialogState, key: str, checked: bool, label: str) -> DialogState:
        """Toggle a focused checkbox when needed and verify its new state."""
        if state.checked.get(key) == checked:
            return state
        self._press("spc")
        state = self._wait_for_state(lambda current: current.checked.get(key) == checked)
        if state.checked.get(key) != checked:
            raise RuntimeError(f"Checkbox {label!r} did not change state")
        return state

    def _to_top(self, state: DialogState, identity, key: str = "pgup") -> DialogState:
        """Page upward until the observed focused item no longer changes."""
        for _ in range(self._limit):
            next_state = self._move(state, key, identity)
            if identity(next_state) == identity(state):
                return state
            state = next_state
        raise RuntimeError("Dialog navigation exceeded its safety limit while seeking the top")

    def _seek(
        self, state: DialogState, identity, matches, label: str, *, start="pgup"
    ) -> DialogState:
        """Return the first matching focused item after seeking the list boundary."""
        state = self._to_top(state, identity, start)
        for _ in range(self._limit):
            if matches(identity(state)):
                return state
            next_state = self._move(state, "down", identity)
            if next_state is state:
                break
            state = next_state
        raise RuntimeError(self._missing(label, state))

    def _move(self, state: DialogState, key: str, identity) -> DialogState:
        """Send one directional key and wait for focused-item identity to change."""
        previous = identity(state)
        self._press(key)
        next_state = self._wait_for_state(lambda current: identity(current) != previous)
        return state if identity(next_state) == previous else next_state

    def _wait_for_state(self, predicate) -> DialogState:
        """Wait for a parsed dialog-state predicate, falling back after a boundary timeout."""

        def changed(snapshot: ScreenSnapshot) -> bool:
            """Apply a state predicate only to complete parseable dialog frames."""
            try:
                return predicate(self._parse_current(snapshot))
            except RuntimeError:
                return False

        try:
            return self._parse_current(
                self.s.vga_wait_snapshot(
                    changed,
                    timeout=self._transition_timeout,
                    rows=self._current.view.bounds.bottom if self._current is not None else None,
                    interval=self._transition_interval,
                )
            )
        except TimeoutError:
            return self.capture()

    def _parse_current(self, snapshot: ScreenSnapshot) -> DialogState:
        """Parse a transition frame as the dialog currently being manipulated."""
        state = self.parse(
            snapshot,
            title=self._current.title if self._current is not None else None,
        )
        self._current = state
        return state

    def _press(self, key: str) -> None:
        """Send one QMP key without leaking implementation-level trace entries."""
        self.s.kb_press_quiet(key)

    @classmethod
    def _button_states(cls, state: DialogState) -> dict[str, bool]:
        """Return outlined button labels, using color only to identify focus."""
        result: dict[str, bool] = {}
        view = state.view
        lines = view.lines
        for offset in range(1, len(lines) - 2):
            top, middle, bottom = lines[offset : offset + 3]
            for match in cls._button.finditer(top):
                left, right = match.start(), match.end() - 1
                if (
                    middle[left : left + 1] != "│"
                    or middle[right : right + 1] != "│"
                    or bottom[left : right + 1] != f"└{'─' * (right - left - 1)}┘"
                ):
                    continue
                interior = middle[left + 1 : right]
                label = interior.strip()
                if not label:
                    continue
                start = left + 1 + interior.find(label)
                row = state.view.bounds.top + offset + 1
                focused = any(
                    (cell := view.cell(row, state.view.bounds.left + column)).foreground
                    is VgaColor.RED
                    and cell.background is VgaColor.LIGHT_GRAY
                    for column in range(start, start + len(label))
                )
                result[_label(label)] = focused
        return result

    @classmethod
    def _selected_button(cls, state: DialogState) -> str | None:
        """Return the button currently rendered red on light gray."""
        return next(
            (label for label, selected in cls._button_states(state).items() if selected),
            None,
        )

    @staticmethod
    def _missing(label: str, state: DialogState) -> str:
        """Format useful context for a missing semantic dialog target."""
        controls = state.checked or state.selected_radios
        visible = ", ".join(controls) or state.active_item or "none"
        return (
            f"Dialog {state.title!r} could not find {label!r}; active={state.active_item!r}, "
            f"focused={state.focused_checkbox or state.focused_radio!r}, "
            f"visible={visible!r}"
        )
