from __future__ import annotations

from dataclasses import dataclass

from ..fdisk import Fdisk
from ..session import InstallSession, Match


@dataclass(slots=True)
class PerlInstallerOptions:
    boot_command: str = ""
    hostname: str = "redhat"
    domain: str = "retro.net"
    ip: str = "10.0.2.15"
    netmask: str = "255.255.255.0"
    network: str = "10.0.2.0"
    broadcast: str = "10.0.2.255"
    gateway: str = "10.0.2.2"
    nameserver: str = "10.0.2.3"


class PerlInstaller:
    """Reusable actions for Red Hat's 1.x-3.x Perl/dialog installer."""

    def __init__(
        self, session: InstallSession, options: PerlInstallerOptions | None = None
    ) -> None:
        self.s = session
        self.o = options or PerlInstallerOptions()

    @property
    def fqdn(self) -> str:
        return f"{self.o.hostname}.{self.o.domain}"

    def step(self, screen: str, *keys: str) -> None:
        self.s.vga_wait(screen)
        self.s.kb_press(*keys)

    def boot(self) -> None:
        self.s.vga_wait("boot:", match=Match.LINE)
        self.s.kb_type(self.o.boot_command, enter=True)

    def load_ramdisk(self, image: str) -> None:
        self.step("VFS: Insert ramdisk floppy and press ENTER")
        self.s.change_floppy(image)
        self.s.kb_press("ret")

    def load_two_ramdisks(self) -> None:
        self.load_ramdisk("ramdisk1.img")
        self.step("RHL: Insert ramdisk 2 floppy and press ENTER")
        self.s.change_floppy("ramdisk2.img")
        self.s.kb_press("ret")

    def insert_boot_disk(self) -> None:
        self.step("Please insert your BOOT disk")
        self.s.change_floppy("boot.img")
        self.s.kb_press("ret")

    def partition(self, prompt: str) -> None:
        self.s.vga_wait(prompt)
        self.s.kb_press("alt-f2")
        self.s.serial_shell_start()
        Fdisk(self.s).partition()
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit()
        self.s.kb_press("alt-f1")
        self.step(prompt, "n")

    def configure_network(self, *, network_first: bool = False) -> None:
        o = self.o
        self.s.kb_press("y")
        fields = [
            ("What hostname have you selected for this computer?", o.hostname, 0),
            ("What domain name is this computer part of?", o.domain, 0),
            (
                "What is the fully qualified domain name (FQDN) of this computer?",
                self.fqdn,
                30,
            ),
            ("What is the IP address of this computer?", o.ip, 0),
        ]
        network_fields = [
            ("What is the network address of this computer?", o.network, 15),
            ("What is the netmask used by this computer?", o.netmask, 15),
        ]
        fields += network_fields if network_first else network_fields[::-1]
        fields.append(("What is the broadcast address used by this computer?", o.broadcast, 15))
        for prompt, value, erase in fields:
            self.s.vga_wait(prompt)
            self.s.kb_repeat("backspace", erase)
            self.s.kb_type(value, enter=True)
        self.step("Does this computer use a gateway?", "y")
        self._replace("What is the IP address of the gateway used by this computer?", o.gateway)
        self.step("Does this computer use a nameserver?", "y")
        self._replace("What is the IP address of the nameserver?", o.nameserver)
        self.step("Does this computer use another nameserver?", "n")
        self.step("Is this correct?", "y")

    def _replace(self, prompt: str, value: str) -> None:
        self.s.vga_wait(prompt)
        self.s.kb_repeat("backspace", 15)
        self.s.kb_type(value, enter=True)

    def format_root(self) -> None:
        self.step("Use the spacebar to select all partitions to format.", "spc", "ret")
        self.step("Are you absolutely certain that you want to format?", "y")

    def configure_x11(self) -> None:
        self.step("Which type of mouse do you have?", "p", "ret")
        self.step("Do you want to autoprobe?", "n")
        for prompt in (
            "Pick a chipset.",
            "How much memory does your card have.",
            "Enter your clocks, separated by spaces.",
            "Please choose a monitor.",
        ):
            self.step(prompt, "ret")

    def finish(self, clock_prompt: str, *, blank_twice: bool = False) -> None:
        self.configure_x11()
        self.step("Networking has already been configured", "y")
        self.step("No Modem", "ret")
        self.step(clock_prompt, "ret")
        self.step("Pick a time zone.", "ret")
        self.step("Select a keymap.", "ret")
        self.step("Do you want to install LILO?", "y")
        self.step("Where do you want to install LILO?", "ret")
        self.step("Do you need to specify hardware parameters?", "n")
        self.step("Do you want to indicate another operating system", "n")
        self.step("Do you want to create a user account?", "n")
        self.step("You will now enter a password for the root user", "ret")
        if blank_twice:
            self.s.kb_press("ret")
        self.s.vga_wait("Reboot now?")
        self.s.kb_press("y")
        self.s.vga_wait("Be sure to remove the boot floppy from your floppy drive!")
        self.s.set_boot("c")
        self.s.kb_press("ret")
        self.s.run_postinst(login=f"{self.fqdn} login:", shell=f"[root@{self.o.hostname} /root]#")
