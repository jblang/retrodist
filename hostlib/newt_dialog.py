"""Recognize and drive the small set of Red Hat C-installer screen dialogs.

This intentionally lives above :mod:`hostlib.vga`: VGA exposes cells and
snapshots, while this module knows the old installer palette and widgets.
"""

from __future__ import annotations

from dataclasses import dataclass
import logging
import re
from typing import Protocol

from .vga import ScreenBounds, ScreenSnapshot, VgaColor

log = logging.getLogger(__name__)


def _label(value: str) -> str:
    """Normalize a rendered item label for exact logical matching."""
    return " ".join(value.split()).casefold()


@dataclass(frozen=True, slots=True)
class DialogState:
    """The controls needed by one supported Red Hat installer dialog."""

    title: str
    bounds: ScreenBounds
    active_item: str | None
    visible_items: tuple[str, ...]
    checklist: tuple[tuple[str, bool], ...]
    focused_checkbox: str | None
    radios: tuple[tuple[str, bool], ...]
    focused_radio: str | None
    snapshot: ScreenSnapshot

    @property
    def checked(self) -> dict[str, bool]:
        """Return visible checklist entries indexed by normalized label."""
        return {_label(name): checked for name, checked in self.checklist}

    @property
    def selected_radios(self) -> dict[str, bool]:
        """Return visible radio entries indexed by normalized label."""
        return {_label(name): selected for name, selected in self.radios}


class _Session(Protocol):
    """Minimal installer-session surface used by ``NewtDialog``."""

    def vga_screen(self, rows: int | None = None) -> ScreenSnapshot:
        """Capture one raw VGA snapshot."""

    def vga_wait_snapshot(
        self,
        predicate,
        *,
        timeout: float | None = None,
        rows: int | None = None,
        interval: float | None = None,
    ) -> ScreenSnapshot:
        """Wait until a raw VGA snapshot satisfies ``predicate``."""

    def kb_press(self, *keys: str) -> None:
        """Send one or more QEMU key names."""

    def kb_press_quiet(self, *keys: str) -> None:
        """Send keys without duplicating this controller's semantic logging."""

    def kb_type_quiet(self, text: str) -> None:
        """Type text without duplicating this controller's semantic logging."""


class NewtDialog:
    """Parse and navigate menus and checklists used by Red Hat C installers."""

    _title = re.compile(r"┤\s*(.*?)\s*├")
    _checklist = re.compile(r"\[([ *])\]\s*(.*?)\s*$")
    _radio = re.compile(r"\(([ *])\)\s*(.*?)\s*$")
    _limit = 100
    _transition_timeout = 0.25
    _transition_interval = 0.0

    def __init__(self, session: _Session) -> None:
        """Bind one synchronous installer session."""
        self.s = session

    def wait_for_title(self, title: str) -> DialogState:
        """Wait specifically for a delimiter-bounded dialog title."""
        log.info("⏳ dialog %s", title)
        snapshot = self.s.vga_wait_snapshot(lambda frame: self._has_title(frame, title))
        state = self.parse(snapshot, title=title)
        log.info("🖥️  dialog %s", state.title)
        return state

    def press_button(self, label: str) -> None:
        """Focus the named rendered button and activate it with Enter."""
        self._activate_button(label, "ret", "press button")

    def advance(self, label: str) -> None:
        """Advance with F12 where the caller source defines that action."""
        target = _label(label)
        state = self.capture()
        rendered = self._buttons(state) | self._outlined_buttons(state)
        if target not in rendered:
            raise RuntimeError(f"Dialog {state.title!r} has no button {label!r}")
        selected = self._selected_button(state)
        if selected is None or selected == target:
            log.info("👇 dialog %s: advance %s", state.title, label)
            self._press("f12")
            return
        self._activate_button(label, "f12", "advance")

    def _activate_button(self, label: str, key: str, action: str) -> None:
        """Focus a rendered button, then use one source-authorized activation key."""
        target = _label(label)
        state = self.capture()
        if (
            key == "f12"
            and target not in self._buttons(state)
            and target in self._outlined_buttons(state)
        ):
            log.info("👇 dialog %s: %s %s", state.title, action, label)
            self._press(key)
            return
        for _ in range(self._limit):
            if self._selected_button(state) == target:
                log.info("👇 dialog %s: %s %s", state.title, action, label)
                self._press(key)
                return
            if target not in self._buttons(state):
                raise RuntimeError(f"Dialog {state.title!r} has no button {label!r}")
            previous_button = self._selected_button(state)
            previous_checkbox = state.focused_checkbox
            previous_radio = state.focused_radio
            self._press("tab")
            state = self._wait_for_state(
                lambda current: self._selected_button(current) != previous_button
                or current.focused_checkbox != previous_checkbox
                or current.focused_radio != previous_radio
            )
        raise RuntimeError(f"Dialog {state.title!r} never focused button {label!r}")

    def capture(self) -> DialogState:
        """Capture and parse the current visible VGA dialog."""
        return self.parse(self.s.vga_screen())

    def enter_text(
        self,
        value: str,
        *,
        field: str | None = None,
        sensitive: bool = False,
    ) -> None:
        """Type one focused dialog entry value and submit that entry."""
        state = self.capture()
        description = field or "focused entry"
        rendered = "<redacted>" if sensitive else repr(value)
        log.info("⌨️  dialog %s: enter %s=%s", state.title, description, rendered)
        quiet = getattr(self.s, "kb_type_quiet", None)
        if quiet is None:
            self.s.kb_type(f"{value}\n")
        else:
            quiet(f"{value}\n")

    def replace_text(self, value: str, *, field: str) -> None:
        """Clear a focused Newt entry with Ctrl-A/Ctrl-K, then submit a value."""
        state = self.capture()
        log.info("⌨️  dialog %s: set %s=%r", state.title, field, value)
        self._press("ctrl-a")
        self._press("ctrl-k")
        self.enter_text(value, field=field)

    @classmethod
    def parse(cls, snapshot: ScreenSnapshot, *, title: str | None = None) -> DialogState:
        """Parse a named dialog, or the geometrically innermost visible dialog."""
        dialogs = cls._dialogs(snapshot)
        if title is not None:
            dialogs = tuple(dialog for dialog in dialogs if _label(dialog[0]) == _label(title))
        if not dialogs:
            raise RuntimeError("Screen does not contain a Red Hat dialog title")
        title, row, column, bounds = max(
            dialogs,
            key=lambda candidate: sum(
                other[3] != candidate[3] and other[3].contains(candidate[3])
                for other in dialogs
            ),
        )
        active = cls._active_item(snapshot, bounds)
        visible_items = cls._visible_menu_items(snapshot, bounds)
        checklist, focused = cls._checklist_items(snapshot, bounds)
        radios, focused_radio = cls._radio_items(snapshot, bounds)
        return DialogState(
            title,
            bounds,
            active,
            visible_items,
            checklist,
            focused,
            radios,
            focused_radio,
            snapshot,
        )

    @classmethod
    def _has_title(cls, snapshot: ScreenSnapshot, title: str) -> bool:
        """Return whether a frame contains the requested dialog title."""
        target = _label(title)
        return any(_label(found[0]) == target for found in cls._find_titles(snapshot))

    @classmethod
    def _find_titles(cls, snapshot: ScreenSnapshot) -> tuple[tuple[str, int, int], ...]:
        """Locate every delimiter-bounded title and its screen coordinates."""
        found = []
        for row, text in enumerate(snapshot.text.splitlines(), 1):
            found.extend(
                (match.group(1), row, match.start() + 1)
                for match in cls._title.finditer(text)
            )
        return tuple(found)

    @classmethod
    def _dialogs(
        cls, snapshot: ScreenSnapshot
    ) -> tuple[tuple[str, int, int, ScreenBounds], ...]:
        """Return every titled dialog paired with its enclosing border."""
        return tuple(
            (title, row, column, cls._bounds(snapshot, row))
            for title, row, column in cls._find_titles(snapshot)
        )

    @staticmethod
    def _bounds(snapshot: ScreenSnapshot, title_row: int) -> ScreenBounds:
        """Return the box enclosing the title's top border."""
        rows = snapshot.text.splitlines()
        for row in range(title_row, 0, -1):
            top = rows[row - 1]
            left, right = top.find("┌"), top.rfind("┐")
            if left < 0 or right <= left:
                continue
            for bottom in range(row + 1, len(rows) + 1):
                base = rows[bottom - 1]
                if base[left : left + 1] == "└" and base[right : right + 1] == "┘":
                    return ScreenBounds(row, left + 1, bottom, right + 1)
        raise RuntimeError("Unable to determine dialog border bounds")

    @classmethod
    def _active_item(cls, snapshot: ScreenSnapshot, bounds: ScreenBounds) -> str | None:
        """Return the yellow-on-blue active menu label inside one dialog."""
        active = cls._active_menu(snapshot, bounds)
        return active[0] if active is not None else None

    @classmethod
    def _active_menu(
        cls, snapshot: ScreenSnapshot, bounds: ScreenBounds
    ) -> tuple[str, int] | None:
        """Return the active menu label and row inside one dialog."""
        rows: dict[int, list[tuple[int, str]]] = {}
        lines = snapshot.text.splitlines()
        for cell in snapshot.select().cells:
            if not (bounds.top < cell.row < bounds.bottom and bounds.left < cell.column < bounds.right):
                continue
            line = lines[cell.row - 1]
            control_text = line[bounds.left - 1 : bounds.right].strip()
            if (
                cls._radio.search(control_text)
                or cls._checklist.search(control_text)
            ):
                continue
            if cell.foreground is VgaColor.YELLOW and cell.background is VgaColor.BLUE:
                rows.setdefault(cell.row, []).append((cell.column, cell.character))
        if not rows:
            return None
        row = min(rows)
        runs: list[list[str]] = []
        current: list[str] = []
        previous = None
        for column, character in rows[row]:
            if previous is not None and column != previous + 1:
                if current:
                    runs.append(current)
                current = []
            current.append(character)
            previous = column
        if current:
            runs.append(current)
        label = "".join(max(runs, key=len)).split("#", 1)[0].split("▒", 1)[0]
        label = label.rstrip(" │")
        return (label, row) if label else None

    @classmethod
    def _visible_menu_items(
        cls, snapshot: ScreenSnapshot, bounds: ScreenBounds
    ) -> tuple[str, ...]:
        """Return every visible row in the menu block containing the highlight."""
        active = cls._active_menu(snapshot, bounds)
        if active is None:
            return ()
        _, active_row = active
        lines = snapshot.text.splitlines()
        scrollbar = cls._scrollbar(snapshot, bounds, active_row)
        scrollbar_column = scrollbar[0] if scrollbar is not None else None

        def menu_row(row: int) -> str | None:
            """Return one list row, excluding headings, buttons, and scrollbars."""
            right = scrollbar_column - 1 if scrollbar_column is not None else bounds.right - 1
            text = lines[row - 1][bounds.left:right].strip()
            if not text:
                return None
            if row == active_row:
                return text
            if not any(
                snapshot.cell(row, column).foreground is VgaColor.BLACK
                and snapshot.cell(row, column).background is VgaColor.LIGHT_GRAY
                and snapshot.cell(row, column).character.strip()
                for column in range(bounds.left + 1, bounds.right)
            ):
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
        return tuple(
            item
            for row in range(top, bottom + 1)
            if (item := menu_row(row)) is not None
        )

    @staticmethod
    def _scrollbar(
        snapshot: ScreenSnapshot, bounds: ScreenBounds, active_row: int
    ) -> tuple[int, int, int] | None:
        """Return the column and visible row range of the list's scrollbar."""
        columns: dict[int, list[int]] = {}
        for cell in snapshot.select().cells:
            if (
                bounds.top < cell.row < bounds.bottom
                and bounds.left < cell.column < bounds.right
                and cell.character in {"#", "▒"}
            ):
                columns.setdefault(cell.column, []).append(cell.row)
        candidates = [
            (column, min(rows), max(rows))
            for column, rows in columns.items()
            if len(set(rows)) >= 2 and min(rows) <= active_row <= max(rows)
        ]
        if not candidates:
            return None
        return max(candidates, key=lambda item: (item[2] - item[1], item[0]))

    @classmethod
    def _checklist_items(
        cls, snapshot: ScreenSnapshot, bounds: ScreenBounds
    ) -> tuple[tuple[tuple[str, bool], ...], str | None]:
        """Return visible checkbox labels, values, and the brown focused entry."""
        rows = snapshot.text.splitlines()
        entries: list[tuple[str, bool]] = []
        focused = None
        for row in range(bounds.top + 1, bounds.bottom):
            text = rows[row - 1][bounds.left - 1 : bounds.right].strip()
            match = cls._checklist.search(text)
            if match is None:
                continue
            name = match.group(2).rstrip(" ▒#│")
            entries.append((name, match.group(1) == "*"))
            if any(
                snapshot.cell(row, column).foreground is VgaColor.BLUE
                and snapshot.cell(row, column).background is VgaColor.BROWN
                for column in range(bounds.left, bounds.right + 1)
            ):
                focused = name
        return tuple(entries), focused

    @classmethod
    def _radio_items(
        cls, snapshot: ScreenSnapshot, bounds: ScreenBounds
    ) -> tuple[tuple[tuple[str, bool], ...], str | None]:
        """Return visible radio labels, selection state, and focused entry."""
        rows = snapshot.text.splitlines()
        entries: list[tuple[str, bool]] = []
        focused = None
        for row in range(bounds.top + 1, bounds.bottom):
            text = rows[row - 1][bounds.left - 1 : bounds.right].strip()
            match = cls._radio.search(text)
            if match is None:
                continue
            name = match.group(2).rstrip(" ▒#│")
            entries.append((name, match.group(1) == "*"))
            if any(
                snapshot.cell(row, column).foreground is VgaColor.BLUE
                and snapshot.cell(row, column).background is VgaColor.BROWN
                for column in range(bounds.left, bounds.right + 1)
            ):
                focused = name
        return tuple(entries), focused

    def select_menu_item(self, label: str, *, label_width: int | None = None) -> None:
        """Find a menu item by visible pages, then align the active row to it."""
        target = _label(label)
        state = self.capture()
        while state.focused_radio is not None or state.focused_checkbox is not None:
            self._press("tab")
            state = self.capture()
        log.info("📋 dialog %s: select menu %s", state.title, label)

        # Scan all rows on each page while moving upward. If the target is
        # already visible, there is no reason to seek the absolute top.
        for _ in range(self._limit):
            if self._focus_visible_menu_item(state, target, label_width):
                return
            next_state = self._move(state, "pgup", self._menu_page_identity)
            if next_state is state:
                break
            state = next_state

        # We are at the top. Scan downward one visible page at a time.
        for _ in range(self._limit):
            if self._focus_visible_menu_item(state, target, label_width):
                return
            next_state = self._move(state, "pgdn", self._menu_page_identity)
            if next_state is state:
                break
            state = next_state
        raise RuntimeError(self._missing(label, state))

    def _focus_visible_menu_item(
        self, state: DialogState, target: str, width: int | None
    ) -> bool:
        """Move within one visible menu page when it contains the target."""
        visible = [self._menu_text(item, width) for item in state.visible_items]
        matches = [index for index, item in enumerate(visible) if _label(item) == target]
        if not matches:
            return False
        if len(matches) != 1:
            raise RuntimeError(
                f"Dialog {state.title!r} has duplicate visible menu matches for {target!r}"
            )
        active = self._menu_text(state.active_item or "", width)
        active_matches = [
            index for index, item in enumerate(visible) if _label(item) == _label(active)
        ]
        if len(active_matches) != 1:
            raise RuntimeError(
                f"Dialog {state.title!r} could not locate active item "
                f"{state.active_item!r} in {state.visible_items!r}"
            )
        offset = matches[0] - active_matches[0]
        direction = "down" if offset > 0 else "up"
        for _ in range(abs(offset)):
            next_state = self._move(
                state,
                direction,
                lambda current: self._menu_text(current.active_item or "", width),
            )
            if next_state is state:
                raise RuntimeError(
                    f"Dialog {state.title!r} stopped before reaching visible item {target!r}"
                )
            state = next_state
        return True

    @staticmethod
    def _menu_page_identity(state: DialogState) -> tuple[str | None, tuple[str, ...]]:
        """Identify both the active row and all visible rows of a menu page."""
        return state.active_item, state.visible_items

    @staticmethod
    def _menu_text(item: str, width: int | None) -> str:
        """Return one semantic menu label, optionally clipping a model column."""
        return item if width is None else item[:width].rstrip()

    def set_radio(self, label: str) -> None:
        """Select one radio-list item, then move focus to the following control."""
        target = _label(label)
        state = self.capture()
        matches = [name for name, _ in state.radios if _label(name) == target]
        if len(matches) != 1:
            raise RuntimeError(
                f"Dialog {state.title!r} expected one radio {label!r}, found {len(matches)}"
            )
        log.info("🔘 dialog %s: select radio %s", state.title, label)

        # First enter the radio list. The blue-on-brown marker cell identifies
        # its focused row even when an unchecked marker contains a blank.
        for _ in range(self._limit):
            if state.focused_radio is not None:
                break
            self._press("tab")
            state = self.capture()
        else:
            raise RuntimeError(f"Dialog {state.title!r} never focused its radio list")

        if _label(state.focused_radio) != target:
            # Establish the top boundary once, then scan the radio list
            # sequentially. Do not use Tab to move between its rows.
            for _ in range(self._limit):
                previous = state.focused_radio
                self._press("up")
                current = self.capture()
                if current.focused_radio == previous:
                    break
                state = current
            else:
                raise RuntimeError(
                    f"Dialog {state.title!r} exceeded the radio-list safety limit"
                )

            for _ in range(self._limit):
                if _label(state.focused_radio or "") == target:
                    break
                previous = state.focused_radio
                self._press("down")
                current = self.capture()
                if current.focused_radio == previous:
                    raise RuntimeError(
                        f"Dialog {state.title!r} could not find radio {label!r}"
                    )
                state = current
            else:
                raise RuntimeError(
                    f"Dialog {state.title!r} exceeded the radio-list safety limit"
                )

        if not state.selected_radios[target]:
            self._select_focused_radio(state, target, label)

        # Radio selection and timezone-list navigation are separate operations.
        # Newt moves from this radio list to the timezone list with one Tab.
        self._press("tab")
        state = self.capture()
        if state.focused_radio is not None:
            raise RuntimeError(
                f"Dialog {state.title!r} did not leave the radio list after Tab"
            )

    def _select_focused_radio(
        self, state: DialogState, target: str, label: str
    ) -> None:
        """Activate a focused radio and verify its selected marker."""
        self._press("spc")
        state = self._wait_for_state(
            lambda current: current.selected_radios.get(target) is True
        )
        if not state.selected_radios.get(target):
            raise RuntimeError(f"Radio {label!r} did not become selected")

    def select_partition(self, device: str) -> None:
        """Select the source-rendered partition row whose first token is ``device``."""
        target = self._partition_device(device)
        state = self.capture()
        log.info("📋 dialog %s: select partition %s", state.title, device)
        state = self._to_top(state, lambda item: item.active_item)
        for _ in range(self._limit):
            if self._partition_device(state.active_item or "") == target:
                return
            next_state = self._move(state, "down", lambda item: item.active_item)
            if next_state is state:
                break
            state = next_state
        raise RuntimeError(self._missing(device, state))

    @staticmethod
    def _partition_device(row: str) -> str:
        """Normalize the optional ``/dev/`` prefix on a partition row's device."""
        tokens = row.split()
        if not tokens:
            return ""
        device = tokens[0].casefold()
        return device.removeprefix("/dev/")

    def move_focus(self, direction: str) -> DialogState:
        """Move a dialog's current control in one named direction."""
        if direction not in {"up", "down", "left", "right"}:
            raise ValueError(f"Unsupported dialog direction: {direction}")
        state = self.capture()
        log.info("📋 dialog %s: move focus %s", state.title, direction)
        self._press(direction)
        return self.capture()

    def toggle_focused_checkbox(self) -> DialogState:
        """Toggle the currently focused checkbox with semantic logging."""
        state = self.capture()
        if state.focused_checkbox is None:
            raise RuntimeError(f"Dialog {state.title!r} has no focused checkbox")
        log.info("☑️  dialog %s: toggle %s", state.title, state.focused_checkbox)
        self._press("spc")
        return self.capture()

    def set_checklist_item(self, label: str, checked: bool) -> None:
        """Set one named checklist item without changing an already-correct value."""
        log.info("☑️  dialog: set checkbox %s=%s", label, checked)
        target = _label(label)
        state = self.capture()
        state = self._to_top(state, lambda item: item.focused_checkbox)
        for _ in range(self._limit):
            focus = _label(state.focused_checkbox or "")
            if focus == target:
                current = state.checked.get(target)
                if current is None:
                    raise RuntimeError(self._missing(label, state))
                if current != checked:
                    self._press("spc")
                    updated = self.capture()
                    if updated.checked.get(target) != checked:
                        raise RuntimeError(f"Checkbox {label!r} did not change state")
                return
            next_state = self._move(state, "down", lambda item: item.focused_checkbox)
            if next_state is state:
                break
            state = next_state
        raise RuntimeError(self._missing(label, state))

    def set_partition_checklist_item(self, device: str, checked: bool) -> None:
        """Set the checklist row whose source-rendered first token is ``device``."""
        target = _label(device)
        state = self._to_top(self.capture(), lambda item: item.focused_checkbox)
        log.info("☑️  dialog %s: set partition %s=%s", state.title, device, checked)
        for _ in range(self._limit):
            focused = state.focused_checkbox or ""
            normalized = _label(focused)
            if normalized == target or normalized.startswith(f"{target} "):
                current = state.checked.get(normalized)
                if current is None:
                    raise RuntimeError(self._missing(device, state))
                if current != checked:
                    self._press("spc")
                    state = self.capture()
                    if state.checked.get(normalized) != checked:
                        raise RuntimeError(
                            f"Partition checkbox {device!r} did not change state"
                        )
                return
            next_state = self._move(state, "down", lambda item: item.focused_checkbox)
            if next_state is state:
                break
            state = next_state
        raise RuntimeError(self._missing(device, state))

    def set_checkbox(self, label: str, checked: bool) -> None:
        """Set one visible standalone checkbox reached through form traversal."""
        target = _label(label)
        state = self.capture()
        matches = [name for name, _ in state.checklist if _label(name) == target]
        if len(matches) != 1:
            raise RuntimeError(
                f"Dialog {state.title!r} expected one checkbox {label!r}, found {len(matches)}"
            )
        log.info("☑️  dialog %s: set checkbox %s=%s", state.title, label, checked)
        for _ in range(self._limit):
            if _label(state.focused_checkbox or "") == target:
                if state.checked[target] != checked:
                    self._press("spc")
                    state = self._wait_for_state(
                        lambda current: current.checked.get(target) == checked
                    )
                    if state.checked.get(target) != checked:
                        raise RuntimeError(f"Checkbox {label!r} did not change state")
                return
            self._press("tab")
            state = self._wait_for_state(
                lambda current: current.focused_checkbox != state.focused_checkbox
                or self._selected_button(current) != self._selected_button(state)
            )
        raise RuntimeError(f"Dialog {state.title!r} never focused checkbox {label!r}")

    def set_checklist_items(
        self,
        choices: dict[str, bool],
        *,
        deselect_unlisted: bool = False,
    ) -> None:
        """Set checklist values in one pass, optionally making them exhaustive.

        With ``deselect_unlisted=True``, every encountered checklist entry not
        named by ``choices`` is cleared. This is the mode used by a future TOML
        package-set list: included names are selected and all others removed.
        """
        pending = {_label(label): (label, checked) for label, checked in choices.items()}
        if len(pending) != len(choices):
            raise ValueError("Checklist choices contain duplicate normalized labels")
        state = self._to_top(self.capture(), lambda item: item.focused_checkbox)
        log.info("☑️  dialog %s: apply %d checkbox selections", state.title, len(choices))
        for _ in range(self._limit):
            focus = _label(state.focused_checkbox or "")
            if focus in pending or deselect_unlisted:
                label, checked = pending.pop(focus, (state.focused_checkbox or "", False))
                current = state.checked.get(focus)
                if current is None:
                    raise RuntimeError(self._missing(label, state))
                if current != checked:
                    log.info("☑️  dialog %s: set %s=%s", state.title, label, checked)
                    self._press("spc")
                    state = self.capture()
                    if state.checked.get(focus) != checked:
                        raise RuntimeError(f"Checkbox {label!r} did not change state")
            if not pending and not deselect_unlisted:
                return
            next_state = self._move(state, "down", lambda item: item.focused_checkbox)
            if next_state is state:
                if not pending:
                    return
                break
            state = next_state
        label, _ = next(iter(pending.values()))
        raise RuntimeError(self._missing(label, state))

    def _to_top(self, state: DialogState, identity) -> DialogState:
        """Page upward until the observed focused item no longer changes."""
        for _ in range(self._limit):
            next_state = self._move(state, "pgup", identity)
            if identity(next_state) == identity(state):
                return state
            state = next_state
        raise RuntimeError("Dialog navigation exceeded its safety limit while seeking the top")

    def _move(self, state: DialogState, key: str, identity) -> DialogState:
        """Send one directional key and wait for focused-item identity to change."""
        previous = identity(state)
        self._press(key)
        waiter = getattr(self.s, "vga_wait_snapshot", None)
        if waiter is None:
            next_state = self.capture()
        else:
            def changed(snapshot: ScreenSnapshot) -> bool:
                """Return whether a captured frame changed the focused identity."""
                try:
                    return identity(self.parse(snapshot)) != previous
                except RuntimeError:
                    return False

            try:
                snapshot = waiter(
                    changed,
                    timeout=self._transition_timeout,
                    interval=self._transition_interval,
                )
                next_state = self.parse(snapshot)
            except TimeoutError:
                next_state = self.capture()
        if identity(next_state) == previous:
            return state
        return next_state

    def _wait_for_state(self, predicate) -> DialogState:
        """Wait for a parsed dialog-state predicate, falling back after a boundary timeout."""
        waiter = getattr(self.s, "vga_wait_snapshot", None)
        if waiter is None:
            return self.capture()

        def changed(snapshot: ScreenSnapshot) -> bool:
            """Apply a state predicate only to complete parseable dialog frames."""
            try:
                return predicate(self.parse(snapshot))
            except RuntimeError:
                return False

        try:
            return self.parse(
                waiter(
                    changed,
                    timeout=self._transition_timeout,
                    interval=self._transition_interval,
                )
            )
        except TimeoutError:
            return self.capture()

    def _press(self, key: str) -> None:
        """Send one QMP key without leaking implementation-level trace entries."""
        quiet = getattr(self.s, "kb_press_quiet", None)
        if quiet is None:
            self.s.kb_press(key)
        else:
            quiet(key)

    @staticmethod
    def _buttons(state: DialogState) -> set[str]:
        """Return labels rendered in either Red Hat button color pair."""
        result = set()
        pairs = {
            (VgaColor.LIGHT_GRAY, VgaColor.RED),
            (VgaColor.RED, VgaColor.LIGHT_GRAY),
        }
        for row, line in enumerate(state.snapshot.text.splitlines(), 1):
            if not state.bounds.top < row < state.bounds.bottom:
                continue
            run: list[str] = []
            for column in range(state.bounds.left, state.bounds.right + 1):
                cell = state.snapshot.cell(row, column)
                if (cell.foreground, cell.background) in pairs:
                    run.append(cell.character)
                else:
                    text = "".join(run).strip(" │")
                    if text and re.fullmatch(r"[A-Za-z][A-Za-z ]*", text):
                        result.add(_label(text))
                    run = []
            text = "".join(run).strip(" │")
            if text and re.fullmatch(r"[A-Za-z][A-Za-z ]*", text):
                result.add(_label(text))
        return result

    @staticmethod
    def _outlined_buttons(state: DialogState) -> set[str]:
        """Return labels enclosed by complete three-row Newt button borders."""
        result = set()
        rows = state.snapshot.text.splitlines()
        for row in range(state.bounds.top + 1, state.bounds.bottom - 1):
            top = rows[row - 1]
            middle = rows[row]
            bottom = rows[row + 1]
            for left, character in enumerate(top):
                if character != "┌":
                    continue
                right = top.find("┐", left + 1)
                if right <= left + 1:
                    continue
                if (
                    middle[left : left + 1] != "│"
                    or middle[right : right + 1] != "│"
                    or bottom[left : left + 1] != "└"
                    or bottom[right : right + 1] != "┘"
                ):
                    continue
                label = middle[left + 1 : right].strip()
                if label:
                    result.add(_label(label))
        return result

    @classmethod
    def _selected_button(cls, state: DialogState) -> str | None:
        """Return the button currently rendered red on light gray."""
        selected = (VgaColor.RED, VgaColor.LIGHT_GRAY)
        for label in cls._buttons(state):
            for row, line in enumerate(state.snapshot.text.splitlines(), 1):
                if not state.bounds.top < row < state.bounds.bottom:
                    continue
                visible = line[state.bounds.left - 1 : state.bounds.right]
                start = visible.casefold().find(label)
                if start >= 0 and all(
                    (state.snapshot.cell(row, column).foreground,
                     state.snapshot.cell(row, column).background) == selected
                    for column in range(state.bounds.left + start, state.bounds.left + start + len(label))
                ):
                    return label
        return None

    @staticmethod
    def _missing(label: str, state: DialogState) -> str:
        """Format useful context for a missing semantic dialog target."""
        controls = state.checklist or state.radios
        visible = ", ".join(name for name, _ in controls) or state.active_item or "none"
        return (
            f"Dialog {state.title!r} could not find {label!r}; active={state.active_item!r}, "
            f"focused={state.focused_checkbox or state.focused_radio!r}, "
            f"visible={visible!r}"
        )
