from __future__ import annotations

from dataclasses import dataclass
import re

from .session import InstallSession


@dataclass(slots=True)
class Fdisk:
    session: InstallSession

    def partition(self, device: str = "/dev/hda", swap_mb: int = 64) -> None:
        command = f"fdisk {device}"
        if device == "/dev/hda":
            command = f"[ -b {device} ] || mknod {device} b 3 0; {command}"
        self.session.serial_console_echo(f"Partitioning {device}; this may take a while...")
        self.session.serial_shell_send(command, wait=False)
        self._prompt("Command (m for help):", "d")
        deleted, _ = self.session.serial.wait_any(
            "Partition number (1-4):", "No partition is defined yet"
        )
        if deleted == 0:
            self.session.serial.send("1")
            self._prompt("Command (m for help):", "d")
            self._prompt("Partition number (1-4):", "2")
        self._prompt("Command (m for help):", "n")
        self.session.serial.send("p")
        self._prompt("Partition number (1-4):", "1")
        first, _ = self._range("First cylinder")
        self.session.serial.send(str(first))
        self._range("Last cylinder")
        self.session.serial.send(f"+{swap_mb}M")
        self._prompt("Command (m for help):", "n")
        self.session.serial.send("p")
        self._prompt("Partition number (1-4):", "2")
        first, _ = self._range("First cylinder")
        self.session.serial.send(str(first))
        _, last = self._range("Last cylinder")
        self.session.serial.send(str(last))
        self._prompt("Command (m for help):", "t")
        self._prompt("Partition number (1-4):", "1")
        self._prompt("Hex code (type L to list codes):", "82")
        self._prompt("Command (m for help):", "t")
        self._prompt("Partition number (1-4):", "2")
        self._prompt("Hex code (type L to list codes):", "83")
        self._prompt("Command (m for help):", "p")
        self._prompt("Command (m for help):", "w")

    def _prompt(self, prompt: str, answer: str) -> None:
        self.session.serial.wait(prompt)
        self.session.serial.send(answer)

    def _range(self, label: str) -> tuple[int, int]:
        pattern = rf"{re.escape(label)} .*\(\[?(\d+)\]?-\[?(\d+)\]?(?:, default \d+)?\): *$"
        matched = self.session.serial.wait(pattern, regex=True)
        values = re.search(pattern, matched)
        if values is None:
            raise RuntimeError(f"Could not parse fdisk range: {matched}")
        return int(values.group(1)), int(values.group(2))
