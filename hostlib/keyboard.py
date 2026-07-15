"""Translate ASCII text into QEMU qcodes for paced installer keyboard input.

The mapping is deliberately explicit: letters, digits, common US-keyboard
punctuation, Enter, and Tab are supported. Unsupported characters fail rather
than silently producing incorrect guest input.
"""

from __future__ import annotations

_PUNCTUATION = {
    "\t": "tab",
    "\n": "ret",
    "\\": "backslash",
    " ": "spc",
    "!": "shift-1",
    "@": "shift-2",
    "#": "shift-3",
    "$": "shift-4",
    "%": "shift-5",
    "^": "shift-6",
    "&": "shift-7",
    "*": "shift-8",
    "(": "shift-9",
    ")": "shift-0",
    "-": "minus",
    "_": "shift-minus",
    "=": "equal",
    "+": "shift-equal",
    "[": "bracket_left",
    "{": "shift-bracket_left",
    "]": "bracket_right",
    "}": "shift-bracket_right",
    "|": "shift-backslash",
    ";": "semicolon",
    ":": "shift-semicolon",
    "'": "apostrophe",
    '"': "shift-apostrophe",
    "`": "grave_accent",
    "~": "shift-grave_accent",
    ",": "comma",
    "<": "shift-comma",
    ".": "dot",
    ">": "shift-dot",
    "/": "slash",
    "?": "shift-slash",
}


def encode(text: str) -> list[str]:
    """Translate text into QEMU send-key tokens.

    Uppercase and shifted punctuation become hyphen-separated modifier
    sequences suitable for ``Monitor.send_key``.

    Raises:
        ValueError: If ``text`` contains a character outside the supported map.
    """
    keys: list[str] = []
    for character in text:
        if character.isascii() and (character.islower() or character.isdigit()):
            keys.append(character)
        elif character.isascii() and character.isupper():
            keys.append(f"shift-{character.lower()}")
        elif key := _PUNCTUATION.get(character):
            keys.append(key)
        else:
            raise ValueError(f"Unsupported character for QEMU keyboard input: {character!r}")
    return keys
