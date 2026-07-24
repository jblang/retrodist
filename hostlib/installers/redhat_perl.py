"""Automate Red Hat 1.x through 3.x Perl/dialog installer drivers.

The early Red Hat installer is a Perl program which delegates its UI to the
``dialog`` executable.  Replacing that executable with guestlib's serial
adapter makes the widgets observable and avoids brittle VGA screen matching.
Screens that do not use the adapter remain VGA-driven.
"""

from __future__ import annotations

from ..dialog import AnswerText, AnswerTitle
from ..errors import ConfigError
from ..fdisk import Fdisk
from ..schemas import PerlInstallConfig
from ..session import InstallSession, Match


def run_perl_installer(session: InstallSession) -> None:
    """Run an early Red Hat Perl-installer installation."""
    installer = PerlInstaller(session)
    installer.boot()
    config = session.config.install
    assert isinstance(config, PerlInstallConfig)
    flow = config.redhat.flow
    if flow == "1.1":
        installer.load_ramdisk("rootdisk.img")
        installer.prepare_dialog("Welcome to the Red Hat Commercial Linux installation program!")
        installer.dialog.answer(AnswerTitle("msgbox", "Important Copyright Notice", "ok"))
        installer.insert_boot_disk()
    elif flow == "2.1":
        installer.flow_21()
    elif flow == "3.0.3":
        installer.flow_303()
    else:
        raise ConfigError(f"Unknown Red Hat Perl installer flow: {flow}")


class PerlInstaller:
    """Drive Red Hat's Perl installer through its ``dialog`` protocol."""

    def __init__(self, session: InstallSession, config: PerlInstallConfig | None = None) -> None:
        """Bind the typed configuration and dialog transport for one install."""
        self.s = session
        config = config or session.config.install
        assert isinstance(config, PerlInstallConfig)
        self.disk = config.disk
        self.prompts = config.prompts
        self.network = config.network
        self.settings = config.redhat
        self.dialog = session.dialog

    @property
    def fqdn(self) -> str:
        """Return the fully qualified host name configured for the guest."""
        return f"{self.network.hostname}.{self.network.domain}"

    def boot(self) -> None:
        """Send the configured kernel command at the boot prompt."""
        self.s.vga_wait("boot:", match=Match.LINE)
        self.s.kb_type(f"{self.prompts.boot_command}\n")

    def prepare_dialog(self, first_dialog: str) -> None:
        """Install the serial dialog adapter while the first widget is open.

        The installer starts immediately, so this is deliberately invoked only
        after its first dialog is visible.  These root disks lack ``mv``;
        Perl, which the installer already requires, performs the rename.
        """
        self.s.vga_wait(first_dialog)
        self.s.kb_press("alt-f2")
        self.s.serial_shell_start()
        mount = self.disk.fat_mount
        self.s.serial_shell_send(f"mkdir -p {mount}")
        self.s.serial_shell_send(
            f"mount -t {self.disk.fat_filesystem} {self.disk.fat_partition} {mount}"
        )
        self.s.serial_shell_send(
            "perl -e 'rename q{/usr/bin/dialog}, q{/usr/bin/dialog.bak} or die $!'"
        )
        self.s.serial_shell_send(f"cp {mount}/guestlib.d/dialog.sh /usr/bin/dialog")
        self.s.serial_shell_send("chmod 755 /usr/bin/dialog")
        self.s.serial_shell_send(
            "( read first_line < /usr/bin/dialog; "
            '[ "$first_line" = "#!/bin/sh" ] ) && echo DIALOG_REPLACED',
            wait=False,
        )
        self.s.serial.wait("DIALOG_REPLACED", line=True)
        self.s.serial.wait("#", line=True)
        Fdisk(self.s).partition_swap_root(self.disk.target_disk, self.disk.swap_mb)
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit()
        self.s.kb_press("alt-f1")
        # This widget was started by the original binary, before we replaced
        # it. It cannot emit the serial protocol, so close it on the VGA
        # console; every following widget is handled by ``self.dialog``.
        self.s.kb_press("ret")

    def load_ramdisk(self, image: str) -> None:
        """Insert and load one installer ramdisk image."""
        self.s.vga_wait("VFS: Insert ramdisk floppy and press ENTER")
        self.s.change_floppy(image)
        self.s.kb_press("ret")

    def load_two_ramdisks(self) -> None:
        """Load the base and supplemental installer ramdisks."""
        self.load_ramdisk("ramdisk1.img")
        self.s.vga_wait("RHL: Insert ramdisk 2 floppy and press ENTER")
        self.s.change_floppy("ramdisk2.img")
        self.s.kb_press("ret")

    def insert_boot_disk(self) -> None:
        """Reinsert the boot floppy and dismiss the serial boot-media widget."""
        self.s.change_floppy("boot.img")
        self.dialog.answer(AnswerTitle("msgbox", "Boot Floppy", "ok"))

    def flow_21(self) -> None:
        """Install Red Hat 2.1 using structured dialog answers."""
        self.load_two_ramdisks()
        self.prepare_dialog("Welcome to the Red Hat Linux installation program!")
        self.insert_boot_disk()
        self._choose_text_cdrom()
        self.partition()
        self.dialog.answer(AnswerTitle("yesno", "Add Swap", "yes"))
        self.dismiss_swap_error()
        self.configure_network()
        self.dialog.answer(AnswerTitle("yesno", "Success", "yes"))
        self.format_root()
        self.dialog.answer(AnswerTitle("checklist", "Select Series", self._series_21()))
        self.dialog.answer(AnswerTitle("menu", "X Configuration", "SVGA"))
        self._finish()

    def flow_303(self) -> None:
        """Install Red Hat 3.0.3 using structured dialog answers."""
        self.load_two_ramdisks()
        self.prepare_dialog("This script will walk you through each step of the installation.")
        self.dialog.answer(AnswerTitle("yesno", "Color Screen", "yes"))
        self.insert_boot_disk()
        self._choose_text_cdrom()
        self.partition()
        self.dialog.answer(AnswerTitle("yesno", "Add Swap", "yes"))
        self.configure_network()
        self.dialog.answer(AnswerTitle("yesno", "Success", "yes"))
        self.format_root()
        # 3.0.3 marks its recommended series as selected already.
        self.dialog.answer(AnswerTitle("checklist", "Select Series", ""))
        self.dialog.answer(AnswerTitle("menu", "X Configuration", "SVGA"))
        self.dialog.answer(AnswerTitle("yesno", "Select Packages", "no"))
        self.dialog.answer(AnswerTitle("msgbox", "Package Installation", "ok"))
        self._finish(x_vga=True)

    def _choose_text_cdrom(self) -> None:
        """Select the staged CD-ROM source and text-mode installer."""
        self.dialog.answer_until(
            AnswerTitle("menu", "Installation Type", "cdrom", item="Red Hat CDROM"),
            AnswerTitle("menu", "Installation Type", "text", item="Text based install"),
        )

    def partition(self) -> None:
        """Decline the installer helper after initial shell partitioning."""
        self.dialog.answer(AnswerTitle("yesno", "Disk Partitions", "no"))

    def configure_network(self) -> None:
        """Fill the Red Hat static-networking dialogue in sequence."""
        n = self.network
        self.dialog.answer(AnswerTitle("yesno", "Choose", "yes"))
        self.dialog.answer_until(
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What hostname have you selected for this computer? (Example: \ntorgo) ",
                n.hostname,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What domain name is this computer part of? (Example: redhat.com) ",
                n.domain,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the fully qualified domain name (FQDN) of this computer? \n"
                "(Example: torgo.redhat.com) \n",
                self.fqdn,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the IP address of this computer? (Example: 199.183.24.2) \n",
                n.ip,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the network address of this computer? (Example: \n" "199.183.24.0) \n",
                n.network,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the netmask used by this computer? (Example: \n" "255.255.255.0) \n",
                n.netmask,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the broadcast address used by this computer? (Example: \n"
                "199.183.24.255) \n",
                n.broadcast,
            ),
            AnswerText(
                "yesno",
                "Network Configuration",
                "Does this computer use a gateway? \n",
                "yes",
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the IP address of the gateway used by this computer? \n",
                n.gateway,
            ),
            AnswerText(
                "yesno",
                "Network Configuration",
                "Does this computer use a nameserver? \n",
                "yes",
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the IP address of the nameserver? \n",
                n.nameserver,
            ),
            AnswerText(
                "yesno",
                "Network Configuration",
                "Does this computer use another nameserver? \n",
                "no",
            ),
            AnswerTitle("yesno", "Net Config", "yes"),
        )

    def dismiss_swap_error(self) -> None:
        """Continue past the old mkswap failure prompt when QEMU triggers it."""
        try:
            self.s.vga_wait("Error.  Press enter for more info", timeout=2)
        except TimeoutError:
            return
        self.s.kb_press("ret")
        self.s.vga_wait("Press enter to continue.")
        self.s.kb_press("ret")
        self.dialog.answer(AnswerTitle("msgbox", "Format Swap", "ok"))

    def format_root(self) -> None:
        """Select and format the standard root partition."""
        root = f"{self.disk.target_disk}2"
        self.dialog.answer(AnswerTitle("checklist", "Filesystems", f'"{root}"'))
        self.dialog.answer(AnswerTitle("yesno", "Filesystems", "yes"))

    @staticmethod
    def _series_21() -> str:
        """Select the historical 2.1 series set, including X Windows."""
        return '"Applications" "Development" "Documentation" "Games" "Networking" "X Windows"'

    def _finish(self, *, x_vga: bool = False) -> None:
        """Complete the remaining dialog widgets and reboot into the disk."""
        self.dialog.answer(AnswerTitle("menu", "Mouse Configuration", "ps2-bus"))
        if x_vga:
            self._configure_x_vga()
        else:
            self._configure_x()
        self.dialog.answer_until(
            AnswerTitle("yesno", "Choose", "yes"),
            AnswerTitle("menu", "Modem Configuration", "<none>"),
            AnswerTitle("menu", "Clock Configuration", "GMT/UTC"),
            AnswerTitle("menu", "Time Zone", "UTC"),
            AnswerTitle("menu", "Keyboard Configuration", "us.map"),
            AnswerTitle("yesno", "LILO", "yes"),
            AnswerTitle("menu", "LILO Installation", self.disk.target_disk),
            AnswerText(
                "yesno",
                "LILO Configuration",
                "If you needed to specify hardware parameters on the \n"
                "LILO command line to boot the install disk, you will \n"
                "need to add some information to your lilo \n"
                "configuration. \n\n"
                "Do you need to specify hardware parameters? \n",
                "no",
            ),
            AnswerText(
                "yesno",
                "LILO Configuration",
                "Do you want to indicate another operating system as an \n"
                "option for LILO to start? \n",
                "no",
            ),
            AnswerTitle("yesno", "Create User", "no"),
            AnswerTitle("msgbox", "Root Password", "ok"),
        )
        self.s.kb_press("ret", "ret")
        self.dialog.answer(AnswerTitle("yesno", "Installation Completed", "yes"))
        self.s.set_boot("c")
        self.dialog.answer(AnswerTitle("msgbox", "Installation Complete", "ok"))
        self.s.run_postinst(
            login=f"{self.fqdn} login:", shell=f"[root@{self.network.hostname} /root]#"
        )

    def _configure_x(self) -> None:
        """Configure the detected QEMU Cirrus display."""
        safe_mode = "640x480   60Hz      Non-Interlaced"
        self.dialog.answer(AnswerTitle("yesno", "X Configuration", "yes"))
        self.dialog.answer(AnswerTitle("yesno", "X Configuration", "yes"))
        self.dialog.answer(AnswerTitle("yesno", "X Configuration", "yes"))
        self.dialog.answer(AnswerTitle("yesno", "X Configuration", "yes"))
        self.dialog.answer(AnswerTitle("menu", "Monitor Specs", "Generic Monitor"))
        self.dialog.answer(
            AnswerTitle(
                "checklist",
                "X Configuration",
                f'"{safe_mode}"',
            )
        )
        self.dialog.answer(AnswerTitle("menu", "X Configuration", safe_mode))
        self.dialog.answer(AnswerTitle("yesno", "X Configuration", "no"))
        self.dialog.answer(AnswerTitle("checklist", "X Configuration", ""))
        self.dialog.answer(AnswerTitle("menu", "X Configuration", "Two"))

    def _configure_x_vga(self) -> None:
        """Drive Xconfigurator after 3.0.3 chroots into the installed system."""
        steps = (
            ("Do you want to autoprobe?", ("ret",)),
            ("Your chipset appears to be:", ("ret",)),
            ("Kb of memory.", ("ret",)),
            ("Your card appears to have the following clocks:", ("ret",)),
            ("Please choose a monitor.", ("g", "g", "ret")),
            ("Select the modes you wish to include in XF86Config.", ("spc", "ret")),
            ("Choose primary video mode.", ("ret",)),
            ("Do you have such a card?", ("n",)),
            ("There are a large number of configuration options", ("ret",)),
            ("How many buttons are on your mouse?", ("ret",)),
        )
        for prompt, keys in steps:
            self.s.vga_wait(prompt)
            self.s.kb_press(*keys)
