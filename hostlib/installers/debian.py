"""Automate Debian releases built around the menu-driven Dinstall program.

The driver combines VGA menu navigation with the guestlib dialog adapter on
``ttyS3``. Release differences are expressed as option values and conditional
menu steps, while partitioning, first boot, account setup, and staged
post-installation remain shared.
"""

from __future__ import annotations

import re
import shlex

from ..dialog import Answer
from ..fdisk import Fdisk
from ..session import InstallSession, Match
from ..schemas import DinstallInstallConfig


def run_dinstall(session: InstallSession) -> None:
    """Run a Debian Dinstall installation with validated configuration."""
    config = session.config.install
    assert isinstance(config, DinstallInstallConfig)
    boot = config.boot
    session.vga_wait(boot.prompt, match=Match.LINE)
    session.kb_type(boot.command + "\n")
    if boot.root_prompt:
        session.vga_wait(boot.root_prompt, match=Match.LINE)
        session.change_floppy(boot.root_image)
        session.kb_type("\n")
    Dinstall(session).install()


class Dinstall:
    """Drive the Debian Dinstall and first-boot menu sequences.

    Main-menu labels are dispatched to focused handlers because releases expose
    overlapping but differently ordered steps. Dialog choices are matched by
    widget metadata rather than timing.
    """

    menu = r"Debian (GNU/)?Linux( [0-9.]+)? Installation Main Menu"

    def __init__(
        self, session: InstallSession, config: DinstallInstallConfig | None = None
    ) -> None:
        """Initialize the Dinstall driver with typed release configuration."""
        self.s = session
        config = config or session.config.install
        assert isinstance(config, DinstallInstallConfig)
        self.disk = config.disk
        self.locale = config.locale
        self.network = config.network
        self.settings = config.debian
        self.d = session.dialog

    def install(self) -> None:
        """Run the complete Debian Dinstall workflow."""
        self._start()
        self._dispatch()
        self._step(r"Reboot [Tt]he System")
        self.s.set_boot("c")
        self.d.answer(Answer("yesno", "Reboot the system?", "yes"))
        self._first_boot()
        self._postinst()

    def _start(self) -> None:
        """Boot the installer and handle any initial root or driver disks."""
        self.s.vga_wait("Select Color or Monochrome", match=Match.LINE)
        self.s.kb_press("alt-f2")
        self.s.vga_wait("Please press Enter to activate this console.", match=Match.LINE)
        self.s.kb_press("ret")
        self.s.vga_wait("#", match=Match.LINE)
        mount = shlex.quote(self.disk.fat_mount)
        partition = shlex.quote(self.disk.fat_partition)
        filesystem = shlex.quote(self.settings.fat_filesystem or self.disk.fat_filesystem)
        self.s.kb_type(f"mkdir -p {mount}; mount -t {filesystem} {partition} {mount}\n")
        self.s.kb_type(f"[ ! -f {mount}/serial.o ] || insmod {mount}/serial.o\n")
        self.s.serial_shell_start()
        for command in (
            "mv /usr/bin/dialog /usr/bin/dialog.bak",
            f"cp {mount}/guestlib.d/dialog.sh /usr/bin/dialog",
            "chmod 755 /usr/bin/dialog",
        ):
            self.s.serial_shell_send(command)
        Fdisk(self.s).partition_swap_root(self.disk.target_disk, self.disk.swap_mb)
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit()
        self.s.kb_press("alt-f1", "ret")

    def _main(self, answer: str = "Next") -> None:
        """Complete Dinstall's main installation menu."""
        self.d.answer(Answer("menu", self.menu, answer, regex=True))

    def _step(self, item: str) -> None:
        """Select one Dinstall menu step by label."""
        self.d.answer_until(
            Answer("textbox", "Release Notes", "ok"),
            Answer(
                "menu",
                self.menu,
                item,
                regex=True,
                description=True,
                item_regex=True,
                exit=True,
            ),
        )

    def _dispatch(self) -> None:
        """Run the release-specific handler for a Dinstall step."""
        handlers = (
            (r"Next :: Configure the Keyboard", self._keyboard),
            (r"Next :: Initialize and Activate .*Swap", self._swap),
            (r"Next :: Initialize .*Linux.*Partition", self._root),
            (r"Next :: Install the Base System", self._base),
            (r"Next :: Install .*Kernel", self._kernel),
            (r"Next :: Install the Device Drivers", self._drivers),
            (r"Next :: Configure Device Driver Modules", self._modules),
            (r"Next :: Configure the Base System", self._configure_base),
            (r"Next :: Configure the Network", self._network),
            (r"Next :: Make Linux Bootable Directly From Hard Disk", self._lilo),
        )
        choices = [Answer("textbox", "Release Notes", "ok")]
        choices += [
            Answer(
                "menu",
                self.menu,
                handler,
                regex=True,
                item=item,
                item_regex=True,
                exit=i == len(handlers) - 1,
            )
            for i, (item, handler) in enumerate(handlers)
        ]
        self.d.answer_until(*choices)

    def _keyboard(self, _: str) -> None:
        """Select the configured keyboard layout."""
        self._main()
        self.d.answer(Answer("menu", "Select Keyboard", self.locale.keymap))

    def _swap(self, _: str) -> None:
        """Create and initialize the swap partition."""
        self._main()
        self.d.answer_until(
            Answer("menu", r"Select (Disk|Swap) Partition", "/dev/hda1", regex=True),
            Answer("yesno", "Scan for Bad Blocks?", "no"),
            Answer("yesno", "Are You Sure?", "yes", exit=True),
        )

    def _root(self, _: str) -> None:
        """Create, format, and mount the root partition."""
        self._main()
        self.d.answer_until(
            Answer("menu", r"Select (Disk )?Partition", "/dev/hda2", regex=True),
            Answer("yesno", "Scan for Bad Blocks?", "no"),
            Answer("yesno", "Are You Sure?", "yes"),
            Answer("yesno", "Mount as the Root Filesystem?", "yes", exit=True),
        )

    def _base(self, _: str) -> None:
        """Install the Debian base system."""
        self._main()
        self.d.answer_until(
            Answer(
                "menu",
                "Select Installation Medium",
                "already mounted filesystem",
                description=True,
            ),
            Answer("inputbox", "Choose Debian directory", self.disk.fat_mount),
            Answer("menu", "Select Base Archive file", "manually", description=True),
            Answer("inputbox", "Enter the Base Archive directory", self.disk.fat_mount),
            Answer("menu", self.menu, None, regex=True, exit=True),
        )

    def _kernel(self, _: str) -> None:
        """Install or configure the boot kernel."""
        self._main()
        if self.settings.kernel_floppy:
            self.s.change_floppy(self.settings.kernel_floppy)
        self.d.answer_until(
            Answer("menu", "Select Disk Drive", "/dev/fd0"),
            Answer("msgbox", "Please Insert Disk", "ok", exit=True),
            Answer(
                "menu",
                "Select Installation Medium",
                "already mounted filesystem",
                description=True,
            ),
            Answer("inputbox", "Choose Debian directory", self.disk.fat_mount),
            Answer("menu", "Select Base Archive file", "manually", description=True),
            Answer(
                "inputbox",
                "Enter the Base Archive directory",
                self.disk.fat_mount,
                exit=True,
            ),
        )

    def _drivers(self, _: str) -> None:
        """Install optional driver disks."""
        self._main()
        if not self.settings.driver_floppy:
            return
        self.s.change_floppy(self.settings.driver_floppy)
        self.d.answer_until(
            Answer("menu", "Select Disk Drive", "/dev/fd0"),
            Answer("msgbox", "Please Insert Disk", "ok", exit=True),
        )

    def _modules(self, _: str) -> None:
        """Select any configured kernel modules."""
        self._main()
        if self.network.net_module:
            self._module("net", self.network.net_module, self.network.net_module_args)
        if self.settings.fs_module:
            self._module("fs", self.settings.fs_module, "")
        self.d.answer(Answer("menu", "Select Category", "Exit"))

    def _module(self, category: str, module: str, arguments: str) -> None:
        """Install one Dinstall module and return to its category menu."""
        self.d.answer_until(
            Answer("menu", "Select Category", category),
            Answer("menu", rf"Select ({re.escape(category)} )? ?modules", module, regex=True),
            Answer("menu", rf"Module {re.escape(module)} [-+]", "Install", regex=True),
            Answer("inputbox", "Enter Command-Line Arguments", arguments, exit=True),
        )
        self.s.vga_wait("Please press ENTER when you are ready to continue.", match=Match.LINE)
        self.s.kb_press("ret")
        self.d.answer(
            Answer("menu", rf"Select ({re.escape(category)} )? ?modules", "Exit", regex=True)
        )

    def _configure_base(self, _: str) -> None:
        """Configure the installed Debian base system."""
        self._main()
        if self.settings.configure_keyboard:
            self.s.serial.wait("TITLE: Keyboard Setup", line=True)
            self.s.serial.wait("TYPE: yesno", line=True)
            self.s.serial.prompt("RESPONSE:", answer="yes")
        self.s.vga_wait("Which?", match=Match.LINE)
        self.s.kb_type(f"{self.locale.timezone}\n")
        self.s.vga_wait(r"Is your system clock set to GMT( \(y/n\) \[y\])?[?]", match=Match.REGEX)
        self.s.kb_type("y\n")

    def _network(self, _: str) -> None:
        """Configure hostname, domain, and networking."""
        n = self.network
        self._main()
        self.d.answer_until(
            Answer("inputbox", "Please enter your Host name", n.hostname),
            Answer("yesno", "Use a Network?", "yes"),
            Answer("inputbox", "Please enter your Domain name", n.domain),
            Answer("yesno", "Confirm", "yes"),
            Answer("inputbox", "Please Enter IP Address", n.ip),
            Answer("inputbox", "Please Enter Netmask", n.netmask),
            Answer("inputbox", "Please Enter Network Address", n.network),
            Answer("inputbox", "Please Enter Broadcast Address", n.broadcast),
            Answer(
                "menu",
                "Choose Broadcast Address",
                "Last bits set to one",
                description=True,
            ),
            Answer("yesno", "Is there a Gateway?", "yes"),
            Answer("inputbox", "Please Enter Gateway Address", n.gateway),
            Answer("menu", "Locate DNS Server", "2"),
            Answer("inputbox", "Please Enter Name Server Address", n.nameserver),
            Answer("yesno", "Please Confirm", "yes"),
            Answer("yesno", "Use Ethernet?", "yes", exit=True),
            Answer("menu", "Choose network interface", "eth0", exit=True),
        )

    def _lilo(self, _: str) -> None:
        """Install and configure the LILO boot loader."""
        self._main()
        self.d.answer_until(
            Answer("yesno", "Create Master Boot Record?", "yes"),
            Answer("yesno", "Make Linux the Default Boot Partition?", "yes", exit=True),
        )

    def _first_boot(self) -> None:
        """Complete first-boot package and account configuration."""
        self._create_accounts()
        self._finish_finger_information()
        self._enable_shadow_passwords()
        self._quit_dselect()

    def _create_accounts(self) -> None:
        """Set the root password and create the configured ordinary user."""
        o = self.settings
        self.s.vga_wait("Changing password for root", match=Match.LINE)
        self.s.kb_type(f"{o.root_password}\n")
        self.s.kb_type(f"{o.root_password}\n")
        self.s.vga_wait("Enter a username for your account:", match=Match.LINE)
        self.s.kb_type(f"{o.user}\n")
        self.s.vga_wait(f"Changing password for {o.user}", match=Match.LINE)
        self.s.kb_type(f"{o.user_password}\n")
        self.s.kb_type(f"{o.user_password}\n")

    def _finish_finger_information(self) -> None:
        """Advance through optional finger fields and confirm the result."""
        while True:
            try:
                self.s.vga_wait(
                    r"^Is (the|this finger) information correct\?? \[y/n\]\??",
                    match=Match.REGEX,
                    timeout=0.1,
                )
                break
            except TimeoutError:
                self.s.kb_press("ret")
        self.s.kb_type("y\n")

    def _enable_shadow_passwords(self) -> None:
        """Enable shadow passwords when offered and reach the next stage."""
        shadow = False
        while True:
            try:
                self.s.vga_wait("Press <ENTER> to continue:", match=Match.LINE, timeout=1)
                break
            except TimeoutError:
                if not shadow:
                    try:
                        self.s.vga_wait(
                            "Shall I install shadow passwords? [Y/n]",
                            match=Match.LINE,
                            timeout=0.1,
                        )
                    except TimeoutError:
                        continue
                    self.s.kb_type("y\n")
                    shadow = True
        self.s.kb_press("ret")

    def _quit_dselect(self) -> None:
        """Wait for the first dselect menu and quit it without changes."""
        self.s.vga_wait(
            "Debian Linux `dselect' package handling frontend.",
            "6. [Q]uit        Quit dselect.",
            "Press ENTER to confirm selection.   ^L to redraw screen.",
            match=Match.LINE,
        )
        self.s.kb_press("q", "ret")

    def _postinst(self) -> None:
        """Launch the staged post-installation runtime."""
        o = self.settings
        hostname = self.network.hostname
        self.s.vga_wait("Have fun!", match=Match.LINE)
        if o.relogin:
            self.s.vga_wait(f"{hostname} login:", match=Match.LINE)
            self.s.kb_type("root\n")
            self.s.vga_wait("Password:", match=Match.LINE)
            self.s.kb_type(f"{o.root_password}\n")
        self.s.vga_wait(r"^[^\s]*# *$", match=Match.REGEX)
        prompts = self.s.config.postinst.packages.prompts
        if not prompts:
            self.s.kb_type(f"{self.s.postinst_command}\n")
            return
        screen_prompt = r"^[^\s]*# *$"
        self.s.serial_shell_start(
            screen_prompt=screen_prompt,
            serial_prompt="retro-postinst#",
            screen_match=Match.REGEX,
        )
        self.s.serial_shell_send(self.s.postinst_command, wait=False)
        self.s.serial.answer_any(
            [(prompt.expect, prompt.answer, prompt.regex) for prompt in prompts]
        )
        self.s.serial.wait("Configuration complete!", line=True)
        if not self.s.config.postinst.reboots:
            self.s.serial_shell_exit(screen_prompt=screen_prompt, screen_match=Match.REGEX)
