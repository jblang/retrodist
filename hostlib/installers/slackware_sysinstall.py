"""Automate Slackware ``doinstall`` and ``syssetup`` releases with Sysinstall.

These installers are serial prompt streams rather than menus. The driver boots
to a shell, partitions and formats the target, selects an install type from the
staged package layout, answers package prompts, and performs system setup.
"""

from __future__ import annotations

from ..fdisk import Fdisk
from ..schemas import ConfigModel
from ..session import InstallSession, Match


def run_sysinstall(session: InstallSession) -> None:
    """Run an early Slackware Sysinstall installation."""
    Sysinstall(session).install()


class SysinstallOptions(ConfigModel):
    """Configure early Slackware Sysinstall automation."""

    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    swap_partition: str = "/dev/hda1"
    swap_blocks: int = 64000
    linux_partition: str = "/dev/hda2"
    fat_partition: str = "/dev/hdb1"


class Sysinstall:
    """Drive the pre-Pkgtool Slackware doinstall/syssetup pair.

    Prompt alternatives cover small differences among 1.0-era releases while
    retaining a single ordered installation workflow.
    """

    def __init__(self, session: InstallSession, options: SysinstallOptions | None = None) -> None:
        """Initialize the Sysinstall driver with resolved release options."""
        self.s = session
        self.o = options if options is not None else session.options(SysinstallOptions)

    def _prompt(self, *questions: str, answer: str, regex: bool = False) -> None:
        """Wait for a Sysinstall question and type its answer."""
        self.s.serial.prompt(*questions, answer=answer, regex=regex)

    def _install_type(self) -> str:
        """Select the configured Sysinstall installation type."""
        install = self.s.qemu_dir / "fat/install"
        return (
            "3"
            if (install / "x1").is_dir() and (install / "t1").is_dir()
            else ("2" if (install / "x1").is_dir() else "1")
        )

    def install(self) -> None:
        """Run partitioning, Sysinstall, and system setup."""
        self._prepare_disk()
        self._run_doinstall()
        self._finish_install()
        self._first_boot()

    def _prepare_disk(self) -> None:
        """Log in, partition the target, and create its filesystems."""
        o = self.o
        self.s.vga_wait("darkstar login:", match=Match.LINE)
        self.s.kb_type("root\n")
        self.s.serial_shell_start(screen_prompt="darkstar:/#")
        Fdisk(self.s).partition(o.target_disk, o.swap_mb)
        self.s.serial.wait("#", line=True)
        for command in (
            f"mkswap {o.swap_partition} {o.swap_blocks}",
            f"swapon {o.swap_partition}",
            f"mke2fs {o.linux_partition}",
        ):
            self.s.serial_shell_send(command)

    def _run_doinstall(self) -> None:
        """Start doinstall and answer source and package-selection prompts."""
        o = self.o
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

    def _finish_install(self) -> None:
        """Write missing fstab entries and reboot from the installed disk."""
        o = self.o
        self.s.serial.wait("Installation is complete.", line=True)
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_send(f"echo '{o.swap_partition} none swap sw 0 0' >> /root/etc/fstab")
        self.s.serial_shell_send("echo 'none /proc proc defaults 0 0' >> /root/etc/fstab")
        self.s.set_boot("c")
        self.s.kb_press("ctrl-alt-delete")

    def _first_boot(self) -> None:
        """Log in after the reboot and launch staged post-install setup."""
        self.s.vga_wait("darkstar login:", match=Match.LINE)
        self.s.kb_type("root\n")
        self.s.vga_wait("darkstar:/#", match=Match.LINE)
        self.s.kb_type(f"{self.s.postinst_command}\n")

    def _packages(self) -> None:
        """Answer package prompts and satisfy an optional boot-disk request.

        Some releases require writable media during package selection. A blank
        1.44 MiB image is created only when that prompt appears; modem detection
        marks the end of this phase.
        """
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
