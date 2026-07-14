from __future__ import annotations

from dataclasses import dataclass
import re

from ..dialog import Choice
from ..fdisk import Fdisk
from ..session import InstallSession, Match


@dataclass(slots=True)
class DinstallOptions:
    hostname: str = "debian"
    keymap: str = "us"
    configure_keyboard: bool = False
    kernel_floppy: str | None = None
    driver_floppy: str | None = "drv1440.bin"
    relogin: bool = False
    net_module: str | None = None
    net_module_args: str = ""
    timezone: str = "Etc/UTC"
    root_password: str = "password1"
    user: str = "debian"
    user_password: str = "password1"
    domain: str = "retro.net"
    ip: str = "10.0.2.15"
    netmask: str = "255.255.255.0"
    network: str = "10.0.2.0"
    broadcast: str = "10.0.2.255"
    gateway: str = "10.0.2.2"
    nameserver: str = "10.0.2.3"


class Dinstall:
    menu = r"Debian (GNU/)?Linux( [0-9.]+)? Installation Main Menu"
    fat_mount = "/retro"

    def __init__(self, session: InstallSession, options: DinstallOptions | None = None) -> None:
        self.s = session
        self.o = options or DinstallOptions()
        self.d = session.dialog

    def install(self) -> None:
        self._start()
        self._dispatch()
        self._step(r"Reboot [Tt]he System")
        self.s.set_boot("c")
        self.d.answer(Choice("yesno", "Reboot the system?", "yes"))
        self._first_boot()
        self._postinst()

    def _start(self) -> None:
        self.s.vga_wait("Select Color or Monochrome", match=Match.LINE)
        self.s.kb_press("alt-f2")
        self.s.vga_wait("Please press Enter to activate this console.", match=Match.LINE)
        self.s.kb_press("ret")
        self.s.vga_wait("#", match=Match.LINE)
        self.s.kb_type("mkdir -p /retro; mount -t msdos /dev/hdb1 /retro", enter=True)
        self.s.kb_type("[ ! -f /retro/serial.o ] || insmod /retro/serial.o", enter=True)
        self.s.serial_shell_start()
        for command in (
            "mv /usr/bin/dialog /usr/bin/dialog.bak",
            "cp /retro/guestlib.d/dialog.sh /usr/bin/dialog",
            "chmod 755 /usr/bin/dialog",
        ):
            self.s.serial_shell_send(command)
        Fdisk(self.s).partition()
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit()
        self.s.kb_press("alt-f1", "ret")

    def _main(self, answer: str = "Next") -> None:
        self.d.answer(Choice("menu", self.menu, answer, regex=True))

    def _step(self, item: str) -> None:
        self.d.answer_until(
            Choice("textbox", "Release Notes", "ok"),
            Choice("menu", self.menu, item, regex=True, description=True, item_regex=True, terminal=True),
        )

    def _dispatch(self) -> None:
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
        choices = [Choice("textbox", "Release Notes", "ok")]
        choices += [
            Choice("menu", self.menu, handler, regex=True, item=item, item_regex=True, terminal=i == len(handlers) - 1)
            for i, (item, handler) in enumerate(handlers)
        ]
        self.d.answer_until(*choices)

    def _keyboard(self, _: str) -> None:
        self._main()
        self.d.answer(Choice("menu", "Select Keyboard", self.o.keymap))

    def _swap(self, _: str) -> None:
        self._main()
        self.d.answer_until(
            Choice("menu", r"Select (Disk|Swap) Partition", "/dev/hda1", regex=True),
            Choice("yesno", "Scan for Bad Blocks?", "no"),
            Choice("yesno", "Are You Sure?", "yes", terminal=True),
        )

    def _root(self, _: str) -> None:
        self._main()
        self.d.answer_until(
            Choice("menu", r"Select (Disk )?Partition", "/dev/hda2", regex=True),
            Choice("yesno", "Scan for Bad Blocks?", "no"),
            Choice("yesno", "Are You Sure?", "yes"),
            Choice("yesno", "Mount as the Root Filesystem?", "yes", terminal=True),
        )

    def _base(self, _: str) -> None:
        self._main()
        self.d.answer_until(
            Choice("menu", "Select Installation Medium", "already mounted filesystem", description=True),
            Choice("inputbox", "Choose Debian directory", self.fat_mount),
            Choice("menu", "Select Base Archive file", "manually", description=True),
            Choice("inputbox", "Enter the Base Archive directory", self.fat_mount),
            Choice("menu", self.menu, None, regex=True, terminal=True),
        )

    def _kernel(self, _: str) -> None:
        self._main()
        if self.o.kernel_floppy:
            self.s.change_floppy(self.o.kernel_floppy)
        self.d.answer_until(
            Choice("menu", "Select Disk Drive", "/dev/fd0"),
            Choice("msgbox", "Please Insert Disk", "ok", terminal=True),
            Choice("menu", "Select Installation Medium", "already mounted filesystem", description=True),
            Choice("inputbox", "Choose Debian directory", self.fat_mount),
            Choice("menu", "Select Base Archive file", "manually", description=True),
            Choice("inputbox", "Enter the Base Archive directory", self.fat_mount, terminal=True),
        )

    def _drivers(self, _: str) -> None:
        self._main()
        if not self.o.driver_floppy:
            return
        self.s.change_floppy(self.o.driver_floppy)
        self.d.answer_until(
            Choice("menu", "Select Disk Drive", "/dev/fd0"),
            Choice("msgbox", "Please Insert Disk", "ok", terminal=True),
        )

    def _modules(self, _: str) -> None:
        self._main()
        if self.o.net_module:
            module = self.o.net_module
            self.d.answer_until(
                Choice("menu", "Select Category", "net"),
                Choice("menu", r"Select (net )? ?modules", module, regex=True),
                Choice("menu", rf"Module {re.escape(module)} [-+]", "Install", regex=True),
                Choice("inputbox", "Enter Command-Line Arguments", self.o.net_module_args, terminal=True),
            )
            self.s.vga_wait("Please press ENTER when you are ready to continue.", match=Match.LINE)
            self.s.kb_press("ret")
            self.d.answer(Choice("menu", r"Select (net )? ?modules", "Exit", regex=True))
        self.d.answer(Choice("menu", "Select Category", "Exit"))

    def _configure_base(self, _: str) -> None:
        self._main()
        if self.o.configure_keyboard:
            self.s.serial.wait("TITLE: Keyboard Setup", line=True)
            self.s.serial.wait("TYPE: yesno", line=True)
            self.s.serial.prompt("RESPONSE:", answer="yes")
        self.s.vga_wait("Which?", match=Match.LINE)
        self.s.kb_type(self.o.timezone, enter=True)
        self.s.vga_wait(r"Is your system clock set to GMT( \(y/n\) \[y\])?[?]", match=Match.REGEX)
        self.s.kb_type("y", enter=True)

    def _network(self, _: str) -> None:
        o = self.o
        self._main()
        self.d.answer_until(
            Choice("inputbox", "Please enter your Host name", o.hostname),
            Choice("yesno", "Use a Network?", "yes"),
            Choice("inputbox", "Please enter your Domain name", o.domain),
            Choice("yesno", "Confirm", "yes"),
            Choice("inputbox", "Please Enter IP Address", o.ip),
            Choice("inputbox", "Please Enter Netmask", o.netmask),
            Choice("inputbox", "Please Enter Network Address", o.network),
            Choice("inputbox", "Please Enter Broadcast Address", o.broadcast),
            Choice("menu", "Choose Broadcast Address", "Last bits set to one", description=True),
            Choice("yesno", "Is there a Gateway?", "yes"),
            Choice("inputbox", "Please Enter Gateway Address", o.gateway),
            Choice("menu", "Locate DNS Server", "2"),
            Choice("inputbox", "Please Enter Name Server Address", o.nameserver),
            Choice("yesno", "Please Confirm", "yes"),
            Choice("yesno", "Use Ethernet?", "yes", terminal=True),
            Choice("menu", "Choose network interface", "eth0", terminal=True),
        )

    def _lilo(self, _: str) -> None:
        self._main()
        self.d.answer_until(
            Choice("yesno", "Create Master Boot Record?", "yes"),
            Choice("yesno", "Make Linux the Default Boot Partition?", "yes", terminal=True),
        )

    def _first_boot(self) -> None:
        o = self.o
        self.s.vga_wait("Changing password for root", match=Match.LINE)
        self.s.kb_type(o.root_password, enter=True)
        self.s.kb_type(o.root_password, enter=True)
        self.s.vga_wait("Enter a username for your account:", match=Match.LINE)
        self.s.kb_type(o.user, enter=True)
        self.s.vga_wait(f"Changing password for {o.user}", match=Match.LINE)
        self.s.kb_type(o.user_password, enter=True)
        self.s.kb_type(o.user_password, enter=True)
        while True:
            try:
                self.s.vga_wait(r"^Is (the|this finger) information correct\?? \[y/n\]\??", match=Match.REGEX, timeout=0.1)
                break
            except TimeoutError:
                self.s.kb_press("ret")
        self.s.kb_type("y", enter=True)
        shadow = False
        while True:
            try:
                self.s.vga_wait("Press <ENTER> to continue:", match=Match.LINE, timeout=1)
                break
            except TimeoutError:
                if not shadow:
                    try:
                        self.s.vga_wait("Shall I install shadow passwords? [Y/n]", match=Match.LINE, timeout=0.1)
                    except TimeoutError:
                        continue
                    self.s.kb_type("y", enter=True)
                    shadow = True
        self.s.kb_press("ret")
        self.s.vga_wait("Debian Linux `dselect' package handling frontend.", "6. [Q]uit        Quit dselect.", "Press ENTER to confirm selection.   ^L to redraw screen.", match=Match.LINE)
        self.s.kb_press("q", "ret")

    def _postinst(self) -> None:
        o = self.o
        self.s.vga_wait("Have fun!", match=Match.LINE)
        if o.relogin:
            self.s.vga_wait(f"{o.hostname} login:", match=Match.LINE)
            self.s.kb_type("root", enter=True)
            self.s.vga_wait("Password:", match=Match.LINE)
            self.s.kb_type(o.root_password, enter=True)
        self.s.vga_wait(r"^[^\s]*# *$", match=Match.REGEX)
        self.s.kb_type(self.s.postinst_command, enter=True)
