from __future__ import annotations

from dataclasses import dataclass
import re
from typing import Callable, Protocol

Answer = str | Callable[[str], None] | None


class SerialTransport(Protocol):
    def read_until(self, pattern: re.Pattern[str]) -> str: ...
    def send(self, text: str) -> None: ...
    def mark(self) -> int: ...
    def rewind(self, offset: int) -> None: ...


@dataclass(frozen=True, slots=True)
class Choice:
    widget: str
    title: str
    answer: Answer
    regex: bool = False
    item: str | None = None
    item_regex: bool = False
    description: bool = False
    terminal: bool = False

    def matches(self, screen: "DialogScreen") -> bool:
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
    title: str
    widget: str
    items: tuple[tuple[str, str], ...]

    @classmethod
    def parse(cls, text: str) -> "DialogScreen":
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
    _response = re.compile(r"(?m)^RESPONSE:\s*$")

    def __init__(self, serial: SerialTransport) -> None:
        self.serial = serial

    def answer(self, choice: Choice) -> None:
        self.answer_until(choice)

    def answer_until(self, *choices: Choice) -> None:
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
