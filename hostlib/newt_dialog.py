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

_TITLE = re.compile(r"┤\s*(.*?)\s*├")
_BUTTON = re.compile(r"┌─+┐")
_CHECKLIST = re.compile(r"\[([ *])\]\s*(.*?)\s*$")
_RADIO = re.compile(r"\(([ *])\)\s*(.*?)\s*$")


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


@dataclass(frozen=True, slots=True)
class _Entry:
    """One rendered Newt entry region."""

    row: int
    column: int
    width: int
    text: str


def _cell_runs(cells: list[VgaCell]) -> tuple[tuple[VgaCell, ...], ...]:
    """Split column-ordered cells into contiguous horizontal runs."""
    return tuple(
        tuple(cell for _, cell in run)
        for _, run in groupby(
            enumerate(cells),
            lambda item: item[1].column - item[0],
        )
    )


def _entries(view: ScreenView) -> tuple[_Entry, ...]:
    """Return yellow-on-blue Newt entry regions in traversal order."""
    entries = []
    for row in range(view.bounds.top + 1, view.bounds.bottom):
        entry_cells = [
            cell
            for column in range(view.bounds.left + 1, view.bounds.right)
            if (cell := view.cell(row, column)).foreground is VgaColor.YELLOW
            and cell.background is VgaColor.BLUE
        ]
        for cells in _cell_runs(entry_cells):
            entries.append(
                _Entry(
                    row,
                    cells[0].column,
                    len(cells),
                    "".join(cell.character for cell in cells).rstrip(" _"),
                )
            )
    return tuple(entries)


def _find_entry(state: DialogState, field: str) -> _Entry:
    """Find the Newt entry rendered beside an exact field label."""
    target = _label(field)
    matches = []
    for entry in _entries(state.view):
        line = state.view.lines[entry.row - state.view.bounds.top]
        label = line[1 : entry.column - state.view.bounds.left].strip()
        if _label(label) == target:
            matches.append(entry)
    if len(matches) != 1:
        raise RuntimeError(
            f"Dialog {state.title!r} expected one entry labeled {field!r}, "
            f"found {len(matches)}"
        )
    return matches[0]


def _entry_matches(entry: _Entry, expected: str) -> bool:
    """Match a complete value, or its visible suffix in a scrolling entry."""
    return entry.text == expected or (
        bool(entry.text)
        and len(expected) > entry.width
        and len(entry.text) == entry.width
        and expected.endswith(entry.text)
    )


def _dialog_bounds(
    snapshot: ScreenSnapshot,
    title_row: int,
    line: str,
    title_column: int,
) -> ScreenBounds | None:
    """Find the box corners enclosing one dialog title."""
    left = line.rfind("┌", 0, title_column) + 1
    right = line.find("┐", title_column) + 1
    if left == 0 or right == 0:
        return None

    for bottom in range(title_row + 1, len(snapshot.contents) + 1):
        left_edge = snapshot.cell(bottom, left).character
        right_edge = snapshot.cell(bottom, right).character
        if (left_edge, right_edge) == ("└", "┘"):
            return ScreenBounds(title_row, left, bottom, right)
    return None


def _dialogs(snapshot: ScreenSnapshot) -> tuple[tuple[str, ScreenBounds], ...]:
    """Return every titled dialog paired with its enclosing border."""
    dialogs = []
    for row, text in enumerate(snapshot.text.splitlines(), 1):
        for match in _TITLE.finditer(text):
            bounds = _dialog_bounds(snapshot, row, text, match.start())
            if bounds is not None:
                dialogs.append((match.group(1), bounds))
    return tuple(dialogs)


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


def _menu(view: ScreenView) -> tuple[str | None, tuple[str, ...]]:
    """Return the active list item and the rows in its visible list page."""
    bounds = view.bounds
    lines = view.lines
    highlighted: dict[int, list[VgaCell]] = {}
    for cell in view.cells:
        if (
            bounds.top < cell.row < bounds.bottom
            and bounds.left < cell.column < bounds.right
            and not _RADIO.search(lines[cell.row - bounds.top].strip())
            and not _CHECKLIST.search(lines[cell.row - bounds.top].strip())
            and cell.foreground is VgaColor.YELLOW
            and cell.background is VgaColor.BLUE
        ):
            highlighted.setdefault(cell.row, []).append(cell)
    if not highlighted:
        return None, ()

    active_row = min(highlighted)
    runs = ("".join(cell.character for cell in run) for run in _cell_runs(highlighted[active_row]))
    active = max(runs, key=len).split("#", 1)[0].split("▒", 1)[0].rstrip(" │")
    if not active:
        return None, ()

    scrollbar = _scrollbar(view.cells, bounds, active_row)
    scrollbar_column = scrollbar[0] if scrollbar is not None else None

    def menu_row(row: int) -> str | None:
        """Return one list row, excluding headings, buttons, and scrollbars."""
        right = scrollbar_column - 1 if scrollbar_column is not None else bounds.right - 1
        line = lines[row - bounds.top]
        text = line[1 : right - bounds.left + 1].strip()
        if not text or _RADIO.search(text) or _CHECKLIST.search(text):
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
    visible = tuple(item for row in range(top, bottom + 1) if (item := menu_row(row)) is not None)
    return active, visible


def _marked_items(
    view: ScreenView, pattern: re.Pattern[str]
) -> tuple[dict[str, bool], str | None]:
    """Parse checkbox-like markers, using color only to identify focus."""
    entries = {}
    focused = None
    for offset, text in enumerate(view.lines[1:-1], 1):
        match = pattern.search(text.strip())
        if match is None:
            continue
        row = view.bounds.top + offset
        name = match.group(2).rstrip(" ▒#│")
        entries[_label(name)] = match.group(1) == "*"
        if any(
            (cell := view.cell(row, column)).foreground is VgaColor.BLUE
            and cell.background is VgaColor.BROWN
            for column in range(view.bounds.left, view.bounds.right + 1)
        ):
            focused = name
    return entries, focused


def parse_dialog(snapshot: ScreenSnapshot, title: str | None = None) -> DialogState:
    """Parse a named dialog, or the geometrically innermost visible dialog."""
    dialogs = _dialogs(snapshot)
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
    active, visible_items = _menu(view)
    checked, focused_checkbox = _marked_items(view, _CHECKLIST)
    selected_radios, focused_radio = _marked_items(view, _RADIO)
    return DialogState(
        title,
        view,
        active,
        visible_items,
        checked,
        focused_checkbox,
        selected_radios,
        focused_radio,
    )


def _button_states(state: DialogState) -> dict[str, bool]:
    """Return outlined button labels, using color only to identify focus."""
    result: dict[str, bool] = {}
    view = state.view
    for offset, top in enumerate(view.lines[1:-1], 1):
        middle = view.lines[offset + 1]
        for match in _BUTTON.finditer(top):
            left, right = match.start(), match.end() - 1
            interior = middle[left + 1 : right]
            label = interior.strip()
            if not label:
                continue
            start = left + 1 + interior.find(label)
            row = view.bounds.top + offset + 1
            focused = any(
                (cell := view.cell(row, view.bounds.left + column)).foreground is VgaColor.RED
                and cell.background is VgaColor.LIGHT_GRAY
                for column in range(start, start + len(label))
            )
            result[label] = focused
    return result


def _selected_button(state: DialogState) -> str | None:
    """Return the button currently rendered red on light gray."""
    return next(
        (label for label, selected in _button_states(state).items() if selected),
        None,
    )


def _partition_device(row: str) -> str:
    """Normalize the optional ``/dev/`` prefix on a partition row's device."""
    tokens = row.split()
    if not tokens:
        return ""
    return tokens[0].casefold().removeprefix("/dev/")


def _missing(label: str, state: DialogState) -> str:
    """Format useful context for a missing semantic dialog target."""
    controls = state.checked or state.selected_radios
    visible = ", ".join(controls) or state.active_item or "none"
    return (
        f"Dialog {state.title!r} could not find {label!r}; active={state.active_item!r}, "
        f"focused={state.focused_checkbox or state.focused_radio!r}, "
        f"visible={visible!r}"
    )


class NewtDialog:
    """Parse and drive the Newt dialogs used by Red Hat C installers."""

    _navigation_limit = 100
    _transition_timeout = 0.25
    _transition_interval = 0.0

    def __init__(self, session: InstallSession) -> None:
        """Bind one synchronous installer session."""
        self.session = session
        self._current: DialogState | None = None

    def wait_for_title(self, title: str) -> DialogState:
        """Wait until the named dialog is the active innermost dialog."""
        log.info("⏳ %s", title)
        target = _label(title)

        def active(frame: ScreenSnapshot) -> bool:
            """Reject a parent while a closing child dialog still covers it."""
            try:
                return _label(parse_dialog(frame).title) == target
            except RuntimeError:
                return False

        snapshot = self.session.vga_wait_snapshot(active)
        state = parse_dialog(snapshot)
        self._current = state
        log.info("📸 %s:\n%s", title, "\n".join(state.view.lines))
        return state

    def press_button(self, label: str | None = None, *, key: str = "ret") -> None:
        """Activate the named button, or the dialog's default button."""
        target = _label(label) if label is not None else None
        state = self.capture()
        for _ in range(self._navigation_limit):
            buttons = _button_states(state)
            button = next(
                (name for name in buttons if target is None or _label(name) == target),
                None,
            )
            selected = next((name for name, focused in buttons.items() if focused), None)
            if button is None:
                if label is None:
                    raise RuntimeError(f"Dialog {state.title!r} has no default button")
                raise RuntimeError(f"Dialog {state.title!r} has no button {label!r}")
            if target is None or selected == button or (key == "f12" and selected is None):
                log.info("👇 Press %s", button)
                self._press(key)
                return
            previous_checkbox = state.focused_checkbox
            previous_radio = state.focused_radio
            self._press("tab")
            state = self._wait_for_state(
                lambda current: _selected_button(current) != selected
                or current.focused_checkbox != previous_checkbox
                or current.focused_radio != previous_radio
            )
        raise RuntimeError(f"Dialog {state.title!r} never focused button {label!r}")

    def advance(self, label: str | None = None) -> None:
        """Advance with F12 where the caller source defines that action."""
        self.press_button(label, key="f12")

    def capture(self) -> DialogState:
        """Capture and parse through the current dialog's bottom row."""
        rows = self._current.view.bounds.bottom if self._current is not None else None
        return self._parse_current(self.session.vga_screen(rows))

    def set_fields(self, fields: dict[str, str], *, sensitive: bool = False) -> None:
        """Replace labeled entries in mapping order, then verify without advancing."""
        if not fields:
            raise ValueError("fields must not be empty")
        state = self.capture()
        for field in fields:
            _find_entry(state, field)
        for index, (field, value) in enumerate(fields.items()):
            if index:
                self._press("tab")
            rendered = "<redacted>" if sensitive else value or "<blank>"
            log.info("✏️  Edit %s: %s", field.rstrip(" :"), rendered)
            self._press("ctrl-a")
            self._press("ctrl-k")
            self.session.kb_type_quiet(value)
        expected = {field: None if sensitive else value for field, value in fields.items()}
        self._verify_fields(state.title, expected)

    def _verify_fields(self, title: str, expected: dict[str, str | None]) -> None:
        """Wait until every expected value is rendered in its labeled entry."""

        def rendered(snapshot: ScreenSnapshot) -> bool:
            """Recognize all expected values in their labeled entries."""
            try:
                state = parse_dialog(snapshot, title)
                return all(
                    value is None or _entry_matches(_find_entry(state, field), value)
                    for field, value in expected.items()
                )
            except RuntimeError:
                return False

        try:
            snapshot = self.session.vga_wait_snapshot(
                rendered,
                timeout=self._transition_timeout,
                rows=self._current.view.bounds.bottom,
                interval=self._transition_interval,
            )
        except TimeoutError as exc:
            labels = ", ".join(repr(field) for field in expected)
            raise RuntimeError(f"Dialog {title!r} did not render fields {labels}") from exc
        self._parse_current(snapshot)

    def select_menu_item(self, label: str, *, label_width: int | None = None) -> None:
        """Find a menu item by visible pages, then align the active row to it."""
        target = _label(label)
        state = self.capture()
        page_state = lambda current: (current.active_item, current.visible_items)
        for _ in range(self._navigation_limit):
            if state.focused_radio is None and state.focused_checkbox is None:
                break
            self._press("tab")
            state = self.capture()
        else:
            raise RuntimeError(f"Dialog {state.title!r} never focused its menu")
        for direction in ("pgup", "pgdn"):
            for _ in range(self._navigation_limit):
                if self._focus_visible_menu_item(state, target, label_width):
                    log.info("👉 Select %s", label)
                    return
                next_state = self._move(state, direction, page_state)
                if next_state is state:
                    break
                state = next_state
        raise RuntimeError(_missing(label, state))

    def _focus_visible_menu_item(self, state: DialogState, target: str, width: int | None) -> bool:
        """Move within one visible menu page when it contains the target."""

        def displayed(item: str) -> str:
            """Apply an optional source-defined rendered-label width."""
            return item if width is None else item[:width].rstrip()

        visible = [_label(displayed(item)) for item in state.visible_items]
        if target not in visible:
            return False
        if visible.count(target) != 1:
            raise RuntimeError(
                f"Dialog {state.title!r} has duplicate visible menu matches for {target!r}"
            )
        active = _label(displayed(state.active_item or ""))
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
                lambda current: displayed(current.active_item or ""),
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
        for _ in range(self._navigation_limit):
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
            start_key="up",
        )

        if not state.selected_radios[target]:
            self._press("spc")
            state = self._wait_for_state(
                lambda current: current.selected_radios.get(target) is True
            )
            if not state.selected_radios.get(target):
                raise RuntimeError(f"Radio {label!r} did not become selected")

        log.info("🔘 Select %s", label)
        self._press("tab")
        state = self._wait_for_state(lambda current: current.focused_radio is None)
        if state.focused_radio is not None:
            raise RuntimeError(f"Dialog {state.title!r} did not leave the radio list after Tab")

    def select_partition(self, device: str) -> None:
        """Select the source-rendered partition row whose first token is ``device``."""
        target = _partition_device(device)
        state = self.capture()
        self._seek(
            state,
            lambda current: current.active_item,
            lambda value: _partition_device(value or "") == target,
            device,
        )
        log.info("👉 Select %s", device)

    def check_partition(self, device: str) -> None:
        """Check the partition row whose source-rendered first token is ``device``."""
        target = _partition_device(device)
        state = self.capture()
        state = self._seek(
            state,
            lambda current: current.focused_checkbox,
            lambda value: _partition_device(value or "") == target,
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
        for _ in range(self._navigation_limit):
            if _label(state.focused_checkbox or "") == target:
                self._set_checked(state, target, checked, label)
                return
            previous = (state.focused_checkbox, _selected_button(state))
            self._press("tab")
            state = self._wait_for_state(
                lambda current: (
                    current.focused_checkbox,
                    _selected_button(current),
                )
                != previous
            )
        raise RuntimeError(f"Dialog {state.title!r} never focused checkbox {label!r}")

    def set_checklist_items(self, selected: list[str]) -> None:
        """Make the checklist exactly match the selected labels."""
        requested = {_label(label): label for label in selected}
        if len(requested) != len(selected):
            raise ValueError("Checklist choices contain duplicate normalized labels")
        pending = dict(requested)
        state = self._to_start(self.capture(), lambda item: item.focused_checkbox)
        for _ in range(self._navigation_limit):
            focus = _label(state.focused_checkbox or "")
            label = requested.get(focus, state.focused_checkbox or "")
            checked = focus in requested
            current = state.checked.get(focus)
            if current is None:
                raise RuntimeError(_missing(label, state))
            if current != checked:
                state = self._set_checked(state, focus, checked, label)
            pending.pop(focus, None)
            next_state = self._move(state, "down", lambda item: item.focused_checkbox)
            if next_state is state:
                if not pending:
                    return
                break
            state = next_state
        label = next(iter(pending.values()))
        raise RuntimeError(_missing(label, state))

    def _set_checked(self, state: DialogState, key: str, checked: bool, label: str) -> DialogState:
        """Toggle a focused checkbox when needed and verify its new state."""
        if state.checked.get(key) == checked:
            return state
        log.info("%s %s", "✅ Select" if checked else "☑️ Clear", label)
        self._press("spc")
        state = self._wait_for_state(lambda current: current.checked.get(key) == checked)
        if state.checked.get(key) != checked:
            raise RuntimeError(f"Checkbox {label!r} did not change state")
        return state

    def _to_start(self, state: DialogState, observe, key: str = "pgup") -> DialogState:
        """Move toward a control's start until its observed value stops changing."""
        for _ in range(self._navigation_limit):
            next_state = self._move(state, key, observe)
            if next_state is state:
                return state
            state = next_state
        raise RuntimeError("Dialog navigation exceeded its safety limit while seeking the top")

    def _seek(
        self,
        state: DialogState,
        observe,
        matches,
        label: str,
        *,
        start_key: str = "pgup",
    ) -> DialogState:
        """Return the first matching focused item after seeking the list boundary."""
        state = self._to_start(state, observe, start_key)
        for _ in range(self._navigation_limit):
            if matches(observe(state)):
                return state
            next_state = self._move(state, "down", observe)
            if next_state is state:
                break
            state = next_state
        raise RuntimeError(_missing(label, state))

    def _move(self, state: DialogState, key: str, observe) -> DialogState:
        """Send one directional key and wait for the observed value to change."""
        previous = observe(state)
        self._press(key)
        next_state = self._wait_for_state(lambda current: observe(current) != previous)
        return state if observe(next_state) == previous else next_state

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
                self.session.vga_wait_snapshot(
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
        state = parse_dialog(
            snapshot,
            self._current.title if self._current is not None else None,
        )
        self._current = state
        return state

    def _press(self, key: str) -> None:
        """Send one QMP key without leaking implementation-level trace entries."""
        self.session.kb_press_quiet(key)
