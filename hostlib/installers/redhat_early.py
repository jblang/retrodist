"""Automate Red Hat 1.x through 3.x Perl/dialog installers.

These releases have distinct linear flows but reuse boot-disk swaps, fdisk,
static networking, root formatting, X11 selection, and final boot-loader work.
The configured flow names the small release-specific composition.
"""

from __future__ import annotations

from dataclasses import dataclass

from ..fdisk import Fdisk
from ..session import InstallSession, Match
from ..errors import ConfigError


@dataclass(slots=True)
class PerlInstallerOptions:
    """Configure early Red Hat Perl-installer automation."""

    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    boot_command: str = ""
    hostname: str = "redhat"
    domain: str = "retro.net"
    ip: str = "10.0.2.15"
    netmask: str = "255.255.255.0"
    network: str = "10.0.2.0"
    broadcast: str = "10.0.2.255"
    gateway: str = "10.0.2.2"
    nameserver: str = "10.0.2.3"


def run_perl_installer(session: InstallSession, install: dict[str, object]) -> None:
    """Run an early Red Hat Perl-installer installation."""
    redhat = install.get("redhat", {})
    if not isinstance(redhat, dict):
        raise ConfigError("install.redhat must be a table")
    flow = str(redhat.get("flow", ""))
    installer = PerlInstaller(session)
    installer.boot()
    if flow == "1.1":
        installer.load_ramdisk("rootdisk.img")
        installer.step("Welcome to the Red Hat Commercial Linux installation program!", "ret")
        installer.step("Important Copyright Notice", "ret")
        installer.insert_boot_disk()
    elif flow == "2.1":
        installer.load_two_ramdisks()
        installer.step("Welcome to the Red Hat Linux installation program!", "ret")
        installer.insert_boot_disk()
        installer.step("Red Hat supports a number of different sources for installation.", "ret")
        installer.step("Text based install", "t", "ret")
        installer.partition("Do you need to partition your disks?")
        installer.step("Do you want to use this as a swap partition?", "y", "ret", "ret", "ret")
        session.vga_wait("Do you want to configure networking")
        installer.configure_network(network_first=True)
        installer.step("I think I've found the Red Hat CD-ROM", "y")
        installer.format_root()
        session.vga_wait("Select each series that you want to install.")
        session.kb_repeat("down", 3)
        session.kb_press("spc")
        session.kb_repeat("down", 6)
        for _ in range(4):
            session.kb_press("spc", "down")
        session.kb_press("spc")
        session.kb_repeat("down", 3)
        session.kb_press("spc")
        session.kb_repeat("down", 3)
        session.kb_press("spc", "down", "spc", "ret")
        installer.step("Which type of video card you you have?", "s", "ret")
        installer.finish("Is your system clock set to local time", blank_twice=True)
    elif flow == "3.0.3":
        installer.step("This script will walk you through each step of the installation.", "ret")
        installer.step("Color Screen", "ret")
        installer.step("Text based install", "ret")
        installer.partition("Disk Partitions")
        installer.step("Do you want to use this as a swap partition?", "y")
        session.vga_wait("Do you want to configure ethernet TCP/IP networking")
        installer.configure_network()
        installer.format_root()
        installer.step("Select each series that you want to install.", "ret")
        installer.step("Which X server would you like to use?", "s", "ret")
        installer.step("Would you like to select and unselect individual packages", "n")
        installer.step("Package Installation is complete.", "ret")
        installer.finish("How does your system clock store the time?")
    else:
        raise ConfigError(f"Unknown Red Hat Perl installer flow: {flow}")


class PerlInstaller:
    """Provide reusable actions for Red Hat's early Perl/dialog installers.

    Screen waits use VGA because the vendor installer predates the staged
    guestlib dialog adapter. Shared actions encapsulate media swaps and long
    prompt sequences that otherwise obscure the release flow.
    """

    def __init__(
        self, session: InstallSession, options: PerlInstallerOptions | None = None
    ) -> None:
        """Initialize the Perl-installer driver for one Red Hat release."""
        self.s = session
        self.o = options if options is not None else session.options(PerlInstallerOptions)

    @property
    def fqdn(self) -> str:
        """Return the configured fully qualified host name."""
        return f"{self.o.hostname}.{self.o.domain}"

    def step(self, screen: str, *keys: str) -> None:
        """Wait for a VGA prompt and type its answer."""
        self.s.vga_wait(screen)
        self.s.kb_press(*keys)

    def boot(self) -> None:
        """Send the configured kernel command at the boot prompt."""
        self.s.vga_wait("boot:", match=Match.LINE)
        self.s.kb_type(f"{self.o.boot_command}\n")

    def load_ramdisk(self, image: str) -> None:
        """Insert and load one ramdisk image."""
        self.step("VFS: Insert ramdisk floppy and press ENTER")
        self.s.change_floppy(image)
        self.s.kb_press("ret")

    def load_two_ramdisks(self) -> None:
        """Load the base and supplemental ramdisk images."""
        self.load_ramdisk("ramdisk1.img")
        self.step("RHL: Insert ramdisk 2 floppy and press ENTER")
        self.s.change_floppy("ramdisk2.img")
        self.s.kb_press("ret")

    def insert_boot_disk(self) -> None:
        """Reinsert the boot disk after ramdisk loading."""
        self.step("Please insert your BOOT disk")
        self.s.change_floppy("boot.img")
        self.s.kb_press("ret")

    def partition(self, prompt: str) -> None:
        """Partition the target disk through the installer helper shell."""
        self.s.vga_wait(prompt)
        self.s.kb_press("alt-f2")
        self.s.serial_shell_start()
        Fdisk(self.s).partition(self.o.target_disk, self.o.swap_mb)
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit()
        self.s.kb_press("alt-f1")
        self.step(prompt, "n")

    def configure_network(self, *, network_first: bool = False) -> None:
        """Answer early Red Hat network configuration dialogs."""
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
            self.s.kb_type(f"{value}\n")
        self.step("Does this computer use a gateway?", "y")
        self._replace("What is the IP address of the gateway used by this computer?", o.gateway)
        self.step("Does this computer use a nameserver?", "y")
        self._replace("What is the IP address of the nameserver?", o.nameserver)
        self.step("Does this computer use another nameserver?", "n")
        self.step("Is this correct?", "y")

    def _replace(self, prompt: str, value: str) -> None:
        """Select replacement media files for the current release."""
        self.s.vga_wait(prompt)
        self.s.kb_repeat("backspace", 15)
        self.s.kb_type(f"{value}\n")

    def format_root(self) -> None:
        """Format and mount the configured root filesystem."""
        self.step("Use the spacebar to select all partitions to format.", "spc", "ret")
        self.step("Are you absolutely certain that you want to format?", "y")

    def configure_x11(self) -> None:
        """Configure the installer X11 server and mouse."""
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
        """Finish installation and execute post-installation setup."""
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
