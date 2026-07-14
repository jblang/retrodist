from __future__ import annotations

from dataclasses import dataclass

from ..fdisk import Fdisk
from ..session import InstallSession, Match


@dataclass(slots=True)
class SysinstallOptions:
    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    swap_partition: str = "/dev/hda1"
    swap_blocks: int = 64000
    linux_partition: str = "/dev/hda2"
    fat_partition: str = "/dev/hdb1"


class Sysinstall:
    """Driver for the pre-pkgtool Slackware doinstall/syssetup pair."""

    def __init__(self, session: InstallSession, options: SysinstallOptions | None = None) -> None:
        self.s = session
        self.o = options or SysinstallOptions()

    def _prompt(self, *questions: str, answer: str, regex: bool = False) -> None:
        self.s.serial.prompt(*questions, answer=answer, regex=regex)

    def _install_type(self) -> str:
        install = self.s.qemu_dir / "fat/install"
        return (
            "3"
            if (install / "x1").is_dir() and (install / "t1").is_dir()
            else ("2" if (install / "x1").is_dir() else "1")
        )

    def install(self) -> None:
        o = self.o
        self.s.vga_wait("darkstar login:", match=Match.LINE)
        self.s.kb_type("root", enter=True)
        self.s.serial_shell_start(screen_prompt="darkstar:/#")
        Fdisk(self.s).partition(o.target_disk, o.swap_mb)
        self.s.serial.wait("#", line=True)
        for command in (
            f"mkswap {o.swap_partition} {o.swap_blocks}",
            f"swapon {o.swap_partition}",
            f"mke2fs {o.linux_partition}",
        ):
            self.s.serial_shell_send(command)
        self.s.serial_console_echo(
            "Starting Slackware setup; package installation may take a while..."
        )
        self.s.serial_shell_send(f"doinstall {o.linux_partition}", wait=False)
        self._prompt("Where will you be installing Linux from?", answer="2")
        self._prompt(
            "Enter the partition that the source is on (eg. /dev/hda1):",
            answer=o.fat_partition,
        )
        self._prompt("Enter the type of the filesystem (minix/ext2/msdos)", answer="msdos")
        self._prompt("Enter type of install (1 or 2):", answer=self._install_type())
        self._packages()
        self._prompt(r"^[Dd]o you have a mouse \(y/n\)\? *$", answer="n", regex=True)
        self._prompt(
            "LILO (Linux Loader) Installation:",
            "Which option would you like? (1/2/3):",
            answer="2",
        )
        self.s.serial.wait("Installation is complete.", line=True)
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_send(f"echo '{o.swap_partition} none swap sw 0 0' >> /root/etc/fstab")
        self.s.serial_shell_send("echo 'none /proc proc defaults 0 0' >> /root/etc/fstab")
        self.s.set_boot("c")
        self.s.kb_press("ctrl-alt-delete")
        self.s.vga_wait("darkstar login:", match=Match.LINE)
        self.s.kb_type("root", enter=True)
        self.s.vga_wait("darkstar:/#", match=Match.LINE)
        self.s.kb_type(self.s.postinst_command, enter=True)

    def _packages(self) -> None:
        choices = (
            r"^Install package ",
            r"^Insert the disk and press <return> :",
            r"^[Dd]o you have a modem \(y/n\)\?",
            r"^Do you want to be prompted before packages are installed\? \(y/n\):",
        )
        while True:
            matched, _ = self.s.serial.wait_any(*choices, regex=True)
            if matched == 0:
                self.s.serial.send("y")
            elif matched == 1:
                image = self.s.qemu_dir / "bootdisk.img"
                with image.open("wb") as stream:
                    stream.truncate(1440 * 1024)
                self.s.change_floppy(image.name)
                self.s.serial.send("")
            elif matched == 2:
                self.s.serial.send("n")
                return
            else:
                self.s.serial.send("n")
