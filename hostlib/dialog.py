"""Drive the guestlib ``dialog`` line protocol over the automation serial port.

The in-guest adapter emits widget metadata and pauses at ``RESPONSE:``. Choices
match title, widget type, and optional item text; answers may be literal values,
callbacks for nested flows, or ``None`` to leave input for another handler.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
import re
from typing import Callable, Protocol

DialogResponse = str | tuple[str, ...] | Callable[[str], None] | None


class SerialTransport(Protocol):
    """Define the serial operations required by the dialog driver."""

    def read_until(self, pattern: re.Pattern[str]) -> str:
        """Read through the next serial fragment matching a pattern."""
        ...

    def send(self, text: str) -> None:
        """Send one response through the serial transport."""
        ...

    def mark(self) -> int:
        """Return a restorable position in the serial input buffer."""
        ...

    def rewind(self, offset: int) -> None:
        """Restore a previously marked serial input position."""
        ...


@dataclass(frozen=True, slots=True, kw_only=True)
class Answer:
    """Describe one expected dialog exchange and its response.

    Literal titles are matched case-insensitively. Titles, prompt text, and item
    constraints may instead use regular expressions. When ``description`` is
    true, the configured answer selects an item's display text and is
    translated back to the tag expected by ``dialog``. A tuple answer selects
    checklist items by exact tag or by the label after a size prefix.
    """

    widget: str
    title: str
    text: str | None = None
    answer: DialogResponse
    regex: bool = False
    item: str | None = None
    item_regex: bool = False
    description: bool = False
    exit: bool = False
    text_regex: bool = False

    def matches(self, screen: "DialogScreen") -> bool:
        """Return whether this choice matches a parsed dialog screen."""
        title_matches = (
            re.search(self.title, screen.title) is not None
            if self.regex
            else self.title.casefold() == screen.title.casefold()
        )
        type_matches = (
            self.widget == "any"
            or self.widget == screen.widget
            or {self.widget, screen.widget} == {"msgbox", "textbox"}
        )
        if not (title_matches and type_matches):
            return False
        if self.text is not None:
            text = "\n".join(screen.text)
            if self.text_regex:
                if re.search(self.text, text) is None:
                    return False
            elif self.text not in text:
                return False
        if self.item is None:
            return True
        matcher = re.compile(self.item) if self.item_regex else re.compile(re.escape(self.item))
        return any(matcher.search(f"{key} :: {description}") for key, description in screen.items)


def AnswerTitle(
    widget: str,
    title: str,
    answer: DialogResponse,
    /,
    *,
    regex: bool = False,
    item: str | None = None,
    item_regex: bool = False,
    description: bool = False,
    exit: bool = False,
) -> Answer:
    """Build an answer matched by widget type and title."""
    return Answer(
        widget=widget,
        title=title,
        answer=answer,
        regex=regex,
        item=item,
        item_regex=item_regex,
        description=description,
        exit=exit,
    )


def AnswerText(
    widget: str,
    title: str,
    text: str,
    answer: DialogResponse,
    /,
    *,
    regex: bool = False,
    text_regex: bool = False,
) -> Answer:
    """Build an answer additionally matched by prompt text."""
    return Answer(
        widget=widget,
        title=title,
        text=text,
        answer=answer,
        regex=regex,
        text_regex=text_regex,
    )


@dataclass(frozen=True, slots=True)
class DialogScreen:
    """Represent a parsed dialog protocol screen."""

    title: str
    widget: str
    items: tuple[tuple[str, str], ...]
    text: tuple[str, ...] = ()

    @classmethod
    def parse(cls, text: str) -> "DialogScreen":
        """Parse title, widget type, and items from a dialog protocol exchange."""
        fields: dict[str, str] = {}
        items: list[tuple[str, str]] = []
        prompt_text: list[str] = []
        for line in text.replace("\r", "").splitlines():
            if line.startswith("TITLE: "):
                fields["title"] = line.removeprefix("TITLE: ")
            elif line.startswith("TYPE: "):
                fields["widget"] = line.removeprefix("TYPE: ")
            elif line.startswith("TEXT: "):
                prompt_text.append(line.removeprefix("TEXT: "))
            elif line.startswith("ITEM: "):
                key, _, description = line.removeprefix("ITEM: ").partition(" :: ")
                items.append((key, description))
        return cls(
            fields.get("title", ""),
            fields.get("widget", "any"),
            tuple(items),
            tuple(prompt_text),
        )


class Dialog:
    """Match dialog screens and send configured answers.

    ``answer_until`` accepts alternatives in any order, which accommodates
    release-dependent optional screens without weakening individual matches.
    Unexpected screens fail with the titles that were still expected.
    """

    _response = re.compile(r"(?m)^RESPONSE:\s*$")

    def __init__(self, serial: SerialTransport) -> None:
        """Initialize the driver over a synchronous serial transport."""
        self.serial = serial

    def answer(self, choice: Answer) -> None:
        """Answer one expected dialog screen."""
        self.answer_until(choice)

    def answer_until(self, *choices: Answer) -> None:
        """Answer expected screens in any encountered order until all are handled.

        A callback or ``None`` answer rewinds the serial buffer to the start of
        the exchange, allowing another protocol handler to consume it. Literal
        answers are sent immediately and removed from the pending choice set.

        Raises:
            RuntimeError: If the next screen matches none of the pending choices.
        """
        pending = list(choices)
        while pending:
            mark = self.serial.mark()
            screen = DialogScreen.parse(self.serial.read_until(self._response))
            choice = self._matching_choice(screen, pending)
            self._send_answer(choice, screen, mark)
            pending.remove(choice)
            if choice.exit:
                return

    @staticmethod
    def _matching_choice(screen: DialogScreen, pending: list[Answer]) -> Answer:
        """Return the pending choice matching a screen or explain the mismatch."""
        try:
            return next(item for item in pending if item.matches(screen))
        except StopIteration as exc:
            expected = ", ".join(repr(item.title) for item in pending)
            raise RuntimeError(
                f"Unexpected dialog {screen.widget} {screen.title!r}; expected {expected}"
            ) from exc

    def _send_answer(self, choice: Answer, screen: DialogScreen, mark: int) -> None:
        """Send a literal answer or return callback screens to their consumer."""
        if callable(choice.answer):
            self.serial.rewind(mark)
            choice.answer(screen.title)
        elif choice.answer is None:
            self.serial.rewind(mark)
        else:
            self.serial.send(self._resolve_answer(choice, screen))

    @staticmethod
    def _resolve_answer(choice: Answer, screen: DialogScreen) -> str:
        """Resolve a description-based choice to its corresponding item key."""
        answer = choice.answer
        assert isinstance(answer, (str, tuple))
        if isinstance(answer, tuple):
            return Dialog._resolve_selections(answer, screen)
        if not choice.description:
            return answer
        matcher = re.compile(answer) if choice.item_regex else re.compile(re.escape(answer))
        return next(key for key, description in screen.items if matcher.search(description))

    @staticmethod
    def _resolve_selections(selections: tuple[str, ...], screen: DialogScreen) -> str:
        """Resolve readable checklist labels to the tags emitted by dialog."""
        resolved = []
        for selection in selections:
            matches = [
                key
                for key, _ in screen.items
                if key == selection or key.endswith(f" - {selection}")
            ]
            if len(matches) != 1:
                raise RuntimeError(
                    f"Checklist selection {selection!r} matched {len(matches)} items "
                    f"in {screen.title!r}"
                )
            resolved.append(matches[0])
        # A quoted empty word bypasses dialog.sh's "accept defaults" behavior
        # while still producing an empty checklist result for the installer.
        return " ".join(json.dumps(item) for item in resolved) if resolved else '""'
