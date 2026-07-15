"""Drive the guestlib ``dialog`` line protocol over the automation serial port.

The in-guest adapter emits widget metadata and pauses at ``RESPONSE:``. Choices
match title, widget type, and optional item text; answers may be literal values,
callbacks for nested flows, or ``None`` to leave input for another handler.
"""

from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Callable, Protocol

Answer = str | Callable[[str], None] | None


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


@dataclass(frozen=True, slots=True)
class Choice:
    """Describe one expected dialog exchange and its response.

    Titles and item constraints may be literal or regular expressions. When
    ``description`` is true, the configured answer selects an item's display
    text and is translated back to the tag expected by ``dialog``.
    """

    widget: str
    title: str
    answer: Answer
    regex: bool = False
    item: str | None = None
    item_regex: bool = False
    description: bool = False
    terminal: bool = False

    def matches(self, screen: "DialogScreen") -> bool:
        """Return whether this choice matches a parsed dialog screen."""
        title_matches = (
            re.search(self.title, screen.title) is not None
            if self.regex
            else self.title == screen.title
        )
        type_matches = (
            self.widget == "any"
            or self.widget == screen.widget
            or {self.widget, screen.widget} == {"msgbox", "textbox"}
        )
        if not (title_matches and type_matches):
            return False
        if self.item is None:
            return True
        matcher = re.compile(self.item) if self.item_regex else re.compile(re.escape(self.item))
        return any(matcher.search(f"{key} :: {description}") for key, description in screen.items)


@dataclass(frozen=True, slots=True)
class DialogScreen:
    """Represent a parsed dialog protocol screen."""

    title: str
    widget: str
    items: tuple[tuple[str, str], ...]

    @classmethod
    def parse(cls, text: str) -> "DialogScreen":
        """Parse title, widget type, and items from a dialog protocol exchange."""
        fields: dict[str, str] = {}
        items: list[tuple[str, str]] = []
        for line in text.replace("\r", "").splitlines():
            if line.startswith("TITLE: "):
                fields["title"] = line.removeprefix("TITLE: ")
            elif line.startswith("TYPE: "):
                fields["widget"] = line.removeprefix("TYPE: ")
            elif line.startswith("ITEM: "):
                key, _, description = line.removeprefix("ITEM: ").partition(" :: ")
                items.append((key, description))
        return cls(fields.get("title", ""), fields.get("widget", "any"), tuple(items))


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

    def answer(self, choice: Choice) -> None:
        """Answer one expected dialog screen."""
        self.answer_until(choice)

    def answer_until(self, *choices: Choice) -> None:
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
            try:
                choice = next(item for item in pending if item.matches(screen))
            except StopIteration as exc:
                expected = ", ".join(repr(item.title) for item in pending)
                raise RuntimeError(
                    f"Unexpected dialog {screen.widget} {screen.title!r}; expected {expected}"
                ) from exc
            if callable(choice.answer):
                self.serial.rewind(mark)
                choice.answer(screen.title)
            elif choice.answer is None:
                self.serial.rewind(mark)
            else:
                answer = choice.answer
                if choice.description:
                    matcher = (
                        re.compile(answer) if choice.item_regex else re.compile(re.escape(answer))
                    )
                    answer = next(
                        key for key, description in screen.items if matcher.search(description)
                    )
                self.serial.send(answer)
            pending.remove(choice)
            if choice.terminal:
                return
