"""Automate the classic interactive ``fdisk`` bundled with early installers.

The driver communicates through an active serial shell and uses prompts common
to the fdisk variants supplied by configured installers. It replaces the first
two primary partitions with swap and root partitions.
"""

from __future__ import annotations

from dataclasses import dataclass
import re

from .session import InstallSession


@dataclass(slots=True)
class Fdisk:
    """Drive the classic interactive fdisk command interface.

    ``partition_swap_root`` deletes existing primary partitions 1 and 2 when
    present, creates a fixed-size Linux swap partition, assigns the remainder
    to Linux, sets type codes, prints the result, and writes the table.
    """

    session: InstallSession

    def partition_swap_root(
        self, device: str = "/dev/hda", swap_mb: int = 64
    ) -> None:
        """Create swap and root partitions with the guest's interactive fdisk."""
        command = f"fdisk {device}"
        if device == "/dev/hda":
            command = f"[ -b {device} ] || mknod {device} b 3 0; {command}"
        self.session.serial_console_echo(f"Partitioning {device}; this may take a while...")
        self.session.serial_shell_send(command, wait=False)
        self._delete_swap_root()
        self.create_partition(1, f"+{swap_mb}M")
        self.create_partition(2)
        self.set_type(1, "82")
        self.set_type(2, "83")
        self.print_table()
        self.write_table()

    def _delete_swap_root(self) -> None:
        """Delete the first two primary partitions when they already exist."""
        for number in (1, 2):
            if not self.delete_partition(number):
                break

    def delete_partition(self, number: int) -> bool:
        """Delete a primary partition, returning whether it was present."""
        self._answer("Command (m for help):", "d")
        _, match = self.session.serial.wait_any(
            "Partition number (1-4):",
            "No partition is defined yet",
        )
        if match == "No partition is defined yet":
            return False
        self.session.serial.send(str(number))
        return True

    def create_partition(self, number: int, last: str | None = None) -> None:
        """Create a primary partition using the offered cylinder range."""
        self._answer("Command (m for help):", "n")
        self.session.serial.send("p")
        self._answer("Partition number (1-4):", str(number))
        first, _ = self._range("First cylinder")
        self.session.serial.send(str(first))
        _, offered_last = self._range("Last cylinder")
        self.session.serial.send(last or str(offered_last))

    def set_type(self, number: int, code: str) -> None:
        """Assign an fdisk hexadecimal type code to a primary partition."""
        self._answer("Command (m for help):", "t")
        self._answer("Partition number (1-4):", str(number))
        self._answer("Hex code (type L to list codes):", code)

    def print_table(self) -> None:
        """Print the current partition table."""
        self._answer("Command (m for help):", "p")

    def write_table(self) -> None:
        """Write the partition table and exit fdisk."""
        self._answer("Command (m for help):", "w")

    def _answer(self, prompt: str, answer: str) -> None:
        """Wait for an fdisk prompt and send its answer."""
        self.session.serial.wait(prompt)
        self.session.serial.send(answer)

    def _range(self, label: str) -> tuple[int, int]:
        """Read the numeric range offered by an fdisk prompt."""
        pattern = rf"{re.escape(label)} .*\(\[?(\d+)\]?-\[?(\d+)\]?(?:, default \d+)?\): *$"
        matched = self.session.serial.wait(pattern, regex=True)
        values = re.search(pattern, matched)
        if values is None:
            raise RuntimeError(f"Could not parse fdisk range: {matched}")
        return int(values.group(1)), int(values.group(2))
