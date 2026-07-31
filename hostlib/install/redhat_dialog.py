"""Automate Red Hat 1.x through 3.x dialog-based installer drivers.

The early Red Hat installer is a Perl program which delegates its UI to the
``dialog`` executable.  Replacing that executable with guestlib's serial
adapter makes the widgets observable and avoids brittle VGA screen matching.
Screens that do not use the adapter remain VGA-driven.
"""

from __future__ import annotations

import shlex

from ..config import RetroConfig
from ..schemas.redhat import RedHatDialogInstallConfig
from ..session import Match, QemuSession
from .dialog import AnswerText, AnswerTitle, Dialog
from .fdisk import Fdisk
from .postinst import fat_mount_command, run_postinst


def run_redhat_dialog(session: QemuSession, config: RetroConfig) -> None:
    """Run the configured early Red Hat dialog installer variant."""
    options = config.install
    assert isinstance(options, RedHatDialogInstallConfig)
    installer = DialogInstaller(session, config)
    installer.boot()
    if options.variant == "1.1":
        installer.load_ramdisk("rootdisk.img")
        installer.prepare_dialog("Welcome to the Red Hat Commercial Linux installation program!")
        installer.dialog.answer(AnswerTitle("msgbox", "Important Copyright Notice", "ok"))
        installer.insert_boot_disk()
    elif options.variant == "2.1":
        installer.install("Welcome to the Red Hat Linux installation program!", x_vga=False)
    elif options.variant == "3.0.3":
        installer.install(
            "This script will walk you through each step of the installation.",
            x_vga=True,
        )


class DialogInstaller:
    """Drive Red Hat's Perl installer through its ``dialog`` protocol."""

    def __init__(
        self,
        session: QemuSession,
        config: RetroConfig,
        dialog: Dialog | None = None,
    ) -> None:
        """Bind the typed configuration and dialog transport for one install."""
        self.s = session
        self.config = config
        options = config.install
        assert isinstance(options, RedHatDialogInstallConfig)
        self.disk = options.disk
        self.locale = options.locale
        self.prompts = options.prompts
        self.network = options.network
        self.packages = options.packages
        self.accounts = options.accounts
        self.dialog = dialog if dialog is not None else Dialog(session.serial)

    @property
    def fqdn(self) -> str:
        """Return the fully qualified host name configured for the guest."""
        return f"{self.network.hostname}.{self.network.domain}"

    def boot(self) -> None:
        """Send the configured kernel command at the boot prompt."""
        self.s.boot_command(self.prompts.boot_prompt, self.prompts.boot_command)

    def prepare_dialog(self, first_dialog: str) -> None:
        """Install the serial dialog adapter while the first widget is open.

        The installer starts immediately, so this is deliberately invoked only
        after its first dialog is visible.  These root disks lack ``mv``;
        Perl, which the installer already requires, performs the rename.
        """
        self.s.vga_wait(first_dialog)
        self.s.kb_press("alt-f2")
        self.s.serial_shell_start()
        dialog_adapter = shlex.quote(f"{self.disk.fat_mount}/guestlib.d/dialog.sh")
        self.s.serial_shell_send(
            fat_mount_command(
                self.disk.fat_mount,
                self.disk.fat_partition,
                self.disk.fat_filesystem,
            )
        )
        self.s.serial_shell_send(
            "perl -e 'rename q{/usr/bin/dialog}, q{/usr/bin/dialog.bak} or die $!'"
        )
        self.s.serial_shell_send(f"cp {dialog_adapter} /usr/bin/dialog")
        self.s.serial_shell_send("chmod 755 /usr/bin/dialog")
        self.s.serial_shell_send(
            "( read first_line < /usr/bin/dialog; "
            '[ "$first_line" = "#!/bin/sh" ] ) && echo DIALOG_REPLACED',
            wait=False,
        )
        self.s.serial.wait("DIALOG_REPLACED", line=True)
        self.s.serial.wait("#", line=True)
        Fdisk(self.s).partition_swap_root(self.disk.target_disk, self.disk.swap_mb)
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

    def install(self, first_dialog: str, *, x_vga: bool) -> None:
        """Install Red Hat 2.x or 3.x, dispatching release-specific dialogs."""
        self.load_two_ramdisks()
        self.prepare_dialog(first_dialog)
        self.dialog.answer_until(
            AnswerTitle("yesno", "Color Screen", "yes"),
            AnswerTitle("msgbox", "Boot Floppy", None, exit=True),
        )
        self.insert_boot_disk()
        self._choose_text_cdrom()
        self.partition()
        self.dialog.answer(AnswerTitle("yesno", "Add Swap", "yes"))
        self.dismiss_swap_error()
        self.configure_network()
        self.dialog.answer(AnswerTitle("yesno", "Success", "yes"))
        self.format_root()
        self.dialog.answer(
            AnswerTitle(
                "checklist",
                "Select Series",
                tuple(self.packages.package_series),
            )
        )
        self.dialog.answer(AnswerTitle("menu", "X Configuration", "SVGA"))
        self.dialog.answer_until(
            AnswerTitle("yesno", "Select Packages", "no"),
            AnswerTitle("msgbox", "Package Installation", "ok"),
            AnswerTitle("menu", "Mouse Configuration", None, exit=True),
        )
        self._finish(x_vga=x_vga)

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
                "What hostname have you selected for this computer?",
                n.hostname,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What domain name is this computer part of?",
                n.domain,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the fully qualified domain name (FQDN) of this computer?",
                self.fqdn,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the IP address of this computer?",
                n.ip,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the network address of this computer?",
                n.network,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the netmask used by this computer?",
                n.netmask,
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the broadcast address used by this computer?",
                n.broadcast,
            ),
            AnswerText(
                "yesno",
                "Network Configuration",
                "Does this computer use a gateway?",
                "yes",
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the IP address of the gateway used by this computer?",
                n.gateway,
            ),
            AnswerText(
                "yesno",
                "Network Configuration",
                "Does this computer use a nameserver?",
                "yes",
            ),
            AnswerText(
                "inputbox",
                "Network Configuration",
                "What is the IP address of the nameserver?",
                n.nameserver,
            ),
            AnswerText(
                "yesno",
                "Network Configuration",
                "Does this computer use another nameserver?",
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
        """Select and format the configured root partition."""
        self.dialog.answer(
            AnswerTitle("checklist", "Filesystems", f'"{self.disk.root_partition}"')
        )
        self.dialog.answer(AnswerTitle("yesno", "Filesystems", "yes"))

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
            AnswerTitle(
                "menu",
                "Clock Configuration",
                "GMT/UTC" if self.locale.hardware_clock == "utc" else "Local Time",
            ),
            AnswerTitle("menu", "Time Zone", self.locale.timezone),
            AnswerTitle("menu", "Keyboard Configuration", self.locale.keymap),
            AnswerTitle("yesno", "LILO", "yes"),
            AnswerTitle("menu", "LILO Installation", self.disk.target_disk),
            AnswerText(
                "yesno",
                "LILO Configuration",
                "Do you need to specify hardware parameters?",
                "no",
            ),
            AnswerText(
                "yesno",
                "LILO Configuration",
                r"Do you want to indicate another operating system as an\s+"
                r"option for LILO to start\?",
                "no",
                text_regex=True,
            ),
        )
        self._configure_user()
        self.dialog.answer(AnswerTitle("msgbox", "Root Password", "ok"))
        self._set_root_password()
        self.dialog.answer(AnswerTitle("yesno", "Installation Completed", "yes"))
        self.s.set_boot("c")
        self.dialog.answer(AnswerTitle("msgbox", "Installation Complete", "ok"))
        run_postinst(
            self.s,
            self.config,
            self.accounts.root_password or None,
            login=f"{self.fqdn} login:",
            shell=f"[root@{self.network.hostname} /root]#",
        )

    def _configure_user(self) -> None:
        """Create the configured regular user, or skip account creation."""
        user = self.accounts.user
        if user is None:
            self.dialog.answer(AnswerTitle("yesno", "Create User", "no"))
            return
        self.dialog.answer(AnswerTitle("yesno", "Create User", "yes"))
        self.dialog.answer(AnswerTitle("inputbox", "User Name", user))
        self.dialog.answer(
            AnswerTitle(
                "yesno",
                "Home Directory",
                "yes" if self.accounts.user_home else "no",
            )
        )
        self.dialog.answer(
            AnswerText(
                "yesno",
                "Create User",
                "Do you want to create another user account?",
                "no",
            )
        )

    def _set_root_password(self) -> None:
        """Set and confirm the configured root password on either release."""
        password = self.accounts.root_password
        self.s.vga_wait(
            r"(New password \(\? for help\):|Enter new password:)",
            match=Match.REGEX,
        )
        self.s.kb_type(f"{password}\n")
        if not password:
            return
        self.s.vga_wait(
            r"(New password \(again\):|Re-type new password:)",
            match=Match.REGEX,
        )
        self.s.kb_type(f"{password}\n")

    def _configure_x(self) -> None:
        """Configure the detected QEMU Cirrus display."""
        safe_mode = "640x480   60Hz      Non-Interlaced"
        self.dialog.answer_until(
            AnswerText(
                "yesno",
                "X Configuration",
                "Do you want to autoprobe?",
                "yes",
            ),
            AnswerText(
                "yesno",
                "X Configuration",
                r"(?s)Your chipset appears to be:.*Is this correct\?",
                "yes",
                text_regex=True,
            ),
            AnswerText(
                "yesno",
                "X Configuration",
                r"Your card appears to have 2048 Kb of memory\.\s+Is this correct\?",
                "yes",
                text_regex=True,
            ),
            AnswerText(
                "yesno",
                "X Configuration",
                r"(?s)Your card appears to have the following clocks:.*Is this correct\?",
                "yes",
                text_regex=True,
            ),
            AnswerTitle("menu", "Monitor Specs", "Generic Monitor"),
            AnswerText(
                "checklist",
                "X Configuration",
                "Select the modes you wish to include in XF86Config.",
                f'"{safe_mode}"',
            ),
            AnswerText(
                "menu",
                "X Configuration",
                "Choose primary video mode.",
                safe_mode,
            ),
            AnswerText(
                "yesno",
                "X Configuration",
                r"(?s)Cirrus cards with 2MB of videoram.*Do you have such a card\?",
                "no",
                text_regex=True,
            ),
            AnswerText(
                "checklist",
                "X Configuration",
                r"(?s)There are a large number of configuration options that.*"
                r"may \(or may not\) be of use to some people\.",
                "",
                text_regex=True,
            ),
            AnswerText(
                "menu",
                "X Configuration",
                "How many buttons are on your mouse?",
                "Two",
            ),
        )

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
