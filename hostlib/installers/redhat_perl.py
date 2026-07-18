"""Automate Red Hat 1.x through 3.x Perl/dialog installer drivers.

These releases have distinct linear flows but reuse boot-disk swaps, fdisk,
static networking, root formatting, X11 selection, and final boot-loader work.
The configured flow names the small release-specific composition.
"""

from __future__ import annotations

from pydantic import Field

from ..fdisk import Fdisk
from ..schemas import ConfigModel, NetworkConfig
from ..session import InstallSession, Match
from ..errors import ConfigError


class PerlInstallerOptions(ConfigModel):
    """Configure early Red Hat Perl-installer automation."""

    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    boot_command: str = ""
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="redhat"))


def run_perl_installer(session: InstallSession) -> None:
    """Run an early Red Hat Perl-installer installation."""
    installer = PerlInstaller(session)
    installer.boot()
    flow = session.config.redhat_flow.flow
    if flow == "1.1":
        installer.load_ramdisk("rootdisk.img")
        installer.step("Welcome to the Red Hat Commercial Linux installation program!", "ret")
        installer.step("Important Copyright Notice", "ret")
        installer.insert_boot_disk()
    elif flow == "2.1":
        installer._flow_21()
    elif flow == "3.0.3":
        installer._flow_303()
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
        return f"{self.o.network.hostname}.{self.o.network.domain}"

    def step(self, screen: str, *keys: str) -> None:
        """Wait for a VGA prompt and type its answer."""
        self.s.vga_wait(screen)
        self.s.kb_press(*keys)

    def _flow_21(self) -> None:
        """Run the Red Hat 2.1 install and component-selection sequence."""
        self.load_two_ramdisks()
        self.step("Welcome to the Red Hat Linux installation program!", "ret")
        self.insert_boot_disk()
        self.step("Red Hat supports a number of different sources for installation.", "ret")
        self.step("Text based install", "t", "ret")
        self.partition("Do you need to partition your disks?")
        self.step("Do you want to use this as a swap partition?", "y", "ret", "ret", "ret")
        self.s.vga_wait("Do you want to configure networking")
        self.configure_network(network_first=True)
        self.step("I think I've found the Red Hat CD-ROM", "y")
        self.format_root()
        self._select_21_packages()
        self.step("Which type of video card you you have?", "s", "ret")
        self.finish("Is your system clock set to local time", blank_twice=True)

    def _select_21_packages(self) -> None:
        """Navigate the Red Hat 2.1 package-series checklist."""
        self.s.vga_wait("Select each series that you want to install.")
        self.s.kb_repeat("down", 3)
        self.s.kb_press("spc")
        self.s.kb_repeat("down", 6)
        for _ in range(4):
            self.s.kb_press("spc", "down")
        self.s.kb_press("spc")
        self.s.kb_repeat("down", 3)
        self.s.kb_press("spc")
        self.s.kb_repeat("down", 3)
        self.s.kb_press("spc", "down", "spc", "ret")

    def _flow_303(self) -> None:
        """Run the Red Hat 3.0.3 installation sequence."""
        self.step("This script will walk you through each step of the installation.", "ret")
        self.step("Color Screen", "ret")
        self.step("Text based install", "ret")
        self.partition("Disk Partitions")
        self.step("Do you want to use this as a swap partition?", "y")
        self.s.vga_wait("Do you want to configure ethernet TCP/IP networking")
        self.configure_network()
        self.format_root()
        self.step("Select each series that you want to install.", "ret")
        self.step("Which X server would you like to use?", "s", "ret")
        self.step("Would you like to select and unselect individual packages", "n")
        self.step("Package Installation is complete.", "ret")
        self.finish("How does your system clock store the time?")

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
        Fdisk(self.s).partition_swap_root(self.o.target_disk, self.o.swap_mb)
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit()
        self.s.kb_press("alt-f1")
        self.step(prompt, "n")

    def configure_network(self, *, network_first: bool = False) -> None:
        """Answer early Red Hat network configuration dialogs."""
        n = self.o.network
        self.s.kb_press("y")
        fields = [
            ("What hostname have you selected for this computer?", n.hostname, 0),
            ("What domain name is this computer part of?", n.domain, 0),
            (
                "What is the fully qualified domain name (FQDN) of this computer?",
                self.fqdn,
                30,
            ),
            ("What is the IP address of this computer?", n.ip, 0),
        ]
        network_fields = [
            ("What is the network address of this computer?", n.network, 15),
            ("What is the netmask used by this computer?", n.netmask, 15),
        ]
        fields += network_fields if network_first else network_fields[::-1]
        fields.append(("What is the broadcast address used by this computer?", n.broadcast, 15))
        self._network_fields(fields)
        self.step("Does this computer use a gateway?", "y")
        self._replace("What is the IP address of the gateway used by this computer?", n.gateway)
        self.step("Does this computer use a nameserver?", "y")
        self._replace("What is the IP address of the nameserver?", n.nameserver)
        self.step("Does this computer use another nameserver?", "n")
        self.step("Is this correct?", "y")

    def _network_fields(self, fields: list[tuple[str, str, int]]) -> None:
        """Fill a sequence of early Red Hat network text fields."""
        for prompt, value, erase in fields:
            self.s.vga_wait(prompt)
            self.s.kb_repeat("backspace", erase)
            self.s.kb_type(f"{value}\n")

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
        hostname = self.o.network.hostname
        self.s.run_postinst(login=f"{self.fqdn} login:", shell=f"[root@{hostname} /root]#")
