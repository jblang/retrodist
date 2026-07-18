"""Automate Slackware releases that use Pkgtool's ``setup`` program.

The guestlib dialog adapter makes setup menus observable on ``ttyS3``. One
driver covers releases from early floppy sets through CD-ROM distributions by
configuring boot/root prompts, source layout, package selection, and optional
configuration dialogs declaratively.
"""

from __future__ import annotations

import logging

from pydantic import Field

from ..dialog import Choice
from ..fdisk import Fdisk
from ..session import InstallSession, Match
from ..schemas import ConfigModel, NetworkConfig

log = logging.getLogger(__name__)


class PkgtoolOptions(ConfigModel):
    """Configure Slackware Pkgtool automation.

    Options describe target and source media, tagfile/package selection,
    release-specific dialog presence, boot-loader choices, network identity,
    timezone, mail mode, and post-install prompt behavior.
    """

    setup_hostname: str = "slackware"
    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    fat_partition: str = "/dev/hdb1"
    fat_mount: str = "/retro"
    source: str = "/dev/hdc"
    linux_partition: str = "/dev/hda2"
    linux_partition_name: str = "linux"
    lilo_framebuffer: str = "standard"
    install_mode: str | None = None
    tagfile_path: str | None = "/retro/tagfiles"
    package_sets: str = '"A" "AP" "N" "X" "XAP"'
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="darkstar"))
    timezone: str = "UTC"
    modem_speed: str = "38400"
    sendmail_mode: str = "SMTP"
    postinst_prompt: str | None = None
    xwmconfig: bool = False
    source_before_target: bool = False
    simple_lilo: bool = False


def run_pkgtool(session: InstallSession) -> None:
    """Run a Slackware Pkgtool installation with resolved options."""
    boot = session.config.pkgtool_boot
    boot_pkgtool(
        session,
        boot_prompt=boot.boot_prompt or None,
        root_prompt=boot.root_prompt or None,
        root_image=boot.root_image,
        continuation_prompt=boot.continuation_prompt or None,
        keyboard_prompt=boot.keyboard_prompt,
    )


class Pkgtool:
    """Drive Slackware setup and Pkgtool dialogs through guestlib.

    Setup stages are selected from the visible menu, while dialog choices are
    matched structurally. Optional configuration screens are handled as an
    unordered choice set to tolerate release-dependent omissions.
    """

    def __init__(self, session: InstallSession, options: PkgtoolOptions | None = None) -> None:
        """Initialize the Pkgtool driver with resolved release options."""
        self.s = session
        self.o = options if options is not None else session.options(PkgtoolOptions)
        self.d = session.dialog

    def install(self) -> None:
        """Run the complete Slackware setup workflow."""
        self.s.vga_wait(f"{self.o.setup_hostname} login:", match=Match.LINE)
        self.s.kb_type("root\n")
        self._prepare()
        if self.o.install_mode:
            self._setup_step("QUICK")
            self.d.answer(Choice("menu", "CHANGE INSTALL MODE", self.o.install_mode))
        self._setup_step("ADDSWAP")
        self._swap()
        self._target_and_source()
        self._sets()
        log.info("🏗️  Package installation in progress...")
        self._configure()
        self._setup_step("EXIT")
        self.s.set_boot("c")
        self.s.kb_press("ctrl-alt-delete")
        self._postinst()

    def _prepare(self) -> None:
        """Boot install media, partition the disk, and start setup."""
        o = self.o
        self.s.serial_shell_start()
        for command in (
            f"mkdir -p {o.fat_mount}",
            f"mount -t msdos {o.fat_partition} {o.fat_mount}",
            "rm /bin/dialog",
            f"cp {o.fat_mount}/guestlib.d/dialog.sh /bin/dialog",
        ):
            self.s.serial_shell_send(command)
        Fdisk(self.s).partition_swap_root(o.target_disk, o.swap_mb)
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit()
        self.s.kb_type("setup\n")

    def _setup_step(self, answer: str) -> None:
        """Select one item from the Slackware setup menu."""
        self.d.answer(
            Choice("menu", r"Slackware(96)? Linux Setup \(version .*\)", answer, regex=True)
        )

    def _swap(self) -> None:
        """Configure the target swap partition."""
        self.d.answer_until(
            Choice("yesno", "SWAP SPACE DETECTED", "yes"),
            Choice("msgbox", "MKSWAP WARNING", "ok"),
            Choice("yesno", "USE MKSWAP?", "yes"),
            Choice("yesno", "ACTIVATE SWAP SPACE?", "yes"),
            Choice("msgbox", "SWAP SPACE CONFIGURED", "ok"),
            Choice("yesno", "CONTINUE WITH INSTALLATION?", "yes", terminal=True),
        )

    def _target_and_source(self) -> None:
        """Configure the target filesystem and package source."""
        if self.o.source_before_target:
            self._select_source()
        self._select_target()
        self._mount_fat_partition()
        if not self.o.source_before_target:
            self._select_source()

    def _select_target(self) -> None:
        """Select and format the configured Linux target partition."""
        o = self.o
        self.d.answer_until(
            Choice("menu", "Select Linux installation partition:", o.linux_partition),
            Choice("msgbox", "Using this partition for Linux:", "ok"),
            Choice(
                "menu",
                r"(CHOOSE LINUX FILESYSTEM|SELECT FILESYSTEM FOR .*)",
                "ext2",
                regex=True,
            ),
            Choice("menu", r"FORMAT PARTITION( .*)?", "Format", regex=True),
            Choice("menu", r"SELECT INODE DENSITY( .*)?", "4096", regex=True),
            Choice("msgbox", "DONE ADDING LINUX PARTITIONS TO /etc/fstab", "ok"),
            Choice("yesno", "DOS AND OS/2 PARTITION SETUP", "yes", terminal=True),
            Choice(
                "yesno",
                r"FAT/FAT32(/HPFS)? PARTITIONS DETECTED",
                "yes",
                regex=True,
                terminal=True,
            ),
        )

    def _mount_fat_partition(self) -> None:
        """Add the staged FAT partition to the installed filesystem table."""
        o = self.o
        self.d.answer_until(
            Choice("inputbox", "CHOOSE PARTITION", o.fat_partition),
            Choice("menu", "CHOOSE PARTITION", o.fat_partition),
            Choice("menu", "SELECT PARTITION TO ADD TO /etc/fstab", o.fat_partition),
            Choice("inputbox", "SELECT MOUNT POINT", o.fat_mount),
            Choice("inputbox", r"PICK MOUNT POINT FOR .*", o.fat_mount, regex=True),
            Choice("msgbox", "CURRENT DOS/HPFS PARTITION STATUS", "ok"),
            Choice("msgbox", r"DONE ADDING FAT/FAT32(/HPFS)? PARTITIONS", "ok", regex=True),
            Choice("inputbox", "CHOOSE PARTITION", "q"),
            Choice("yesno", "CONTINUE?", "yes", terminal=True),
        )

    def _select_source(self) -> None:
        """Select CD-ROM, staged FAT packages, or a manually chosen source.

        CD-ROM releases expose several alternative discovery dialogs, while a
        FAT source uses the already mounted package directory. Unknown devices
        deliberately fall back to manual selection before automation resumes.
        """
        o = self.o
        if o.source == "/dev/hdc":
            self.d.answer_until(
                Choice("menu", "SOURCE MEDIA SELECTION", "CD-ROM", description=True),
                Choice(
                    "menu",
                    "Install from the Slackware CD-ROM",
                    r"(IDE.*CD drives|ATAPI/IDE CD drives)",
                    description=True,
                    item_regex=True,
                ),
                Choice("menu", "SCAN FOR CD-ROM DRIVE?", "manual"),
                Choice("menu", "SELECT IDE DEVICE", o.source),
                Choice("menu", "MANUAL CD-ROM DEVICE SELECTION", o.source),
                Choice("yesno", r"USING CD-ROM DRIVE:.*", "no", regex=True),
                Choice("menu", "Pick your installation method", "slakware"),
                Choice("menu", "CHOOSE INSTALLATION TYPE", "slakware"),
                Choice("yesno", "CONTINUE?", "yes", terminal=True),
            )
        elif o.source == o.fat_partition:
            self.d.answer(Choice("menu", "SOURCE MEDIA SELECTION", "4"))
            self.d.answer(
                Choice(
                    "inputbox",
                    "INSTALL FROM THE CURRENT FILESYSTEM",
                    f"{o.fat_mount}/packages",
                )
            )
            self.d.answer(Choice("yesno", "CONTINUE?", "yes"))
        else:
            log.warning("Manual package source selection required; automation will resume")
            self.d.answer(Choice("yesno", "CONTINUE?", "yes"))

    def _sets(self) -> None:
        """Select package series and start package installation."""
        mode = "custom path" if self.o.tagfile_path else "default tagfiles"
        self.d.answer_until(
            Choice(
                "checklist",
                r"(PACKAGE |SOFTWARE )?SERIES SELECTION",
                self.o.package_sets,
                regex=True,
            ),
            Choice("yesno", "CONTINUE?", "yes"),
            Choice("menu", "SELECT PROMPTING MODE", mode, description=True, terminal=True),
        )
        if self.o.tagfile_path:
            self.d.answer(
                Choice(
                    "inputbox",
                    "PROVIDE A CUSTOM PATH TO YOUR TAGFILES",
                    self.o.tagfile_path,
                )
            )

    def _configure(self) -> None:
        """Answer boot loader, network, time-zone, and service dialogs."""
        o = self.o
        self.d.answer_until(
            Choice("yesno", "CONFIGURE YOUR SYSTEM?", "yes"),
            Choice("menu", "MAKE BOOTDISK", "continue"),
            Choice("yesno", "MAKE BOOT DISK?", "no"),
            Choice("msgbox", "SKIPPED BOOT DISK CREATION", "ok"),
            Choice("yesno", "MODEM CONFIGURATION", "no"),
            Choice("menu", "MODEM CONFIGURATION", "no modem"),
            Choice("yesno", "MOUSE CONFIGURATION", "no"),
            Choice("menu", "MOUSE CONFIGURATION", "ps2"),
            Choice("yesno", "CONFIGURE CD-ROM?", "no"),
            Choice("yesno", "SCREEN FONT CONFIGURATION", "no"),
            Choice("yesno", "CONSOLE FONT CONFIGURATION", "no"),
            Choice("yesno", "FTAPE CONFIGURATION", "no"),
            Choice("menu", "SET YOUR MODEM SPEED", o.modem_speed),
            Choice("menu", "INSTALL LINUX KERNEL", "skip"),
            Choice("menu", "INSTALL LILO", self._lilo),
            Choice("menu", "LILO INSTALLATION", self._lilo),
            Choice("yesno", "CONFIGURE NETWORK?", self._network),
            Choice("yesno", "GPM CONFIGURATION", "no"),
            Choice("yesno", "ENABLE HOTPLUG SUBSYSTEM AT BOOT?", "no"),
            Choice("yesno", "SELECTION 1.5 CONFIGURATION", "no"),
            Choice("menu", "SENDMAIL CONFIGURATION", self._sendmail),
            Choice("menu", "HARDWARE CLOCK SET TO UTC?", "YES"),
            Choice("menu", "TIMEZONE CONFIGURATION", self._timezone),
            Choice("yesno", "WARNING: NO ROOT PASSWORD DETECTED", "no"),
            Choice("msgbox", "SETUP COMPLETE", "ok", terminal=True),
        )

    def _lilo(self, title: str) -> None:
        """Configure and install LILO for the selected Slackware release."""
        o = self.o
        if o.simple_lilo:
            self.d.answer(Choice("menu", title, "2"))
            return
        if title == "INSTALL LILO":
            self.d.answer(Choice("menu", title, "expert"))
            title = "EXPERT LILO INSTALLATION"
        self.d.answer_until(
            Choice("menu", title, "Begin"),
            Choice("inputbox", r"OPTIONAL (LILO )?append=.* LINE", "", regex=True),
            Choice("menu", "CONFIGURE LILO TO USE FRAME BUFFER CONSOLE?", o.lilo_framebuffer),
            Choice("menu", "SELECT LILO TARGET LOCATION", "MBR"),
            Choice("inputbox", "CONFIRM LOCATION TO INSTALL LILO", o.target_disk),
            Choice("menu", r"CHOOSE LILO (DELAY|TIMEOUT)", "None", regex=True),
            Choice("menu", title, "Linux"),
            Choice("inputbox", "SELECT LINUX PARTITION", o.linux_partition),
            Choice("inputbox", "SELECT PARTITION NAME", o.linux_partition_name),
            Choice("menu", title, "Install", terminal=True),
        )

    def _network(self, title: str) -> None:
        """Configure the Slackware hostname and static network settings."""
        n = self.o.network
        self.d.answer(Choice("yesno", title, "yes"))
        self.d.answer_until(
            Choice("msgbox", "NETWORK CONFIGURATION", ""),
            Choice("inputbox", "ENTER HOSTNAME", n.hostname),
            Choice("inputbox", r"ENTER DOMAINNAME( FOR .*)?", n.domain, regex=True),
            Choice("yesno", "LOOPBACK ONLY?", "no"),
            Choice("menu", r"SETUP IP (ADDRESS )?FOR .*", "static IP", regex=True),
            Choice("inputbox", r"ENTER (LOCAL IP ADDRESS|IP ADDRESS FOR .*)", n.ip, regex=True),
            Choice("inputbox", "ENTER NETWORK ADDRESS", n.network),
            Choice("inputbox", "ENTER BROADCAST ADDRESS", n.broadcast),
            Choice("inputbox", "ENTER GATEWAY ADDRESS", n.gateway),
            Choice("inputbox", r"ENTER NETMASK( .*)?", n.netmask, regex=True),
            Choice("yesno", "USE A NAMESERVER?", "yes"),
            Choice("inputbox", "SELECT NAMESERVER", n.nameserver),
            Choice("menu", "PROBE FOR NETWORK CARD?", "probe"),
            Choice("msgbox", "CARD DETECTED", "ok"),
            Choice("msgbox", "NETWORK SETUP COMPLETE", "ok", terminal=True),
            Choice("yesno", "NETWORK SETUP COMPLETE", "yes", terminal=True),
            Choice("inputmenu", "CONFIRM NETWORK SETUP", "", terminal=True),
        )

    def _timezone(self, title: str) -> None:
        """Select the configured time zone and optional window manager."""
        self.d.answer(Choice("menu", title, self.o.timezone))
        self._xwmconfig()

    def _sendmail(self, title: str) -> None:
        """Select the configured sendmail mode and optional window manager."""
        self.d.answer(Choice("menu", title, self.o.sendmail_mode))
        self._xwmconfig()

    def _xwmconfig(self) -> None:
        """Select the default window manager when its prompt is enabled."""
        if not self.o.xwmconfig:
            return
        try:
            self.s.vga_wait("SELECT DEFAULT WINDOW MANAGER FOR X", timeout=1)
        except TimeoutError:
            return
        self.s.kb_press("spc", "ret")
        self.o.xwmconfig = False

    def _postinst(self) -> None:
        """Launch the staged post-installation runtime."""
        o = self.o
        hostname = o.network.hostname
        self.s.vga_wait(f"{hostname} login:", match=Match.LINE)
        self.s.kb_type("root\n")
        self.s.vga_wait(o.postinst_prompt or f"{hostname}:~#", match=Match.LINE)
        self.s.kb_type(f"{o.fat_mount}/guestlib.d/postinst.sh\n")


def boot_pkgtool(
    session: InstallSession,
    *,
    boot_prompt: str | None = "boot:",
    root_prompt: str | None = None,
    root_image: str = "root.img",
    continuation_prompt: str | None = None,
    keyboard_prompt: bool = False,
    options: PkgtoolOptions | None = None,
) -> None:
    """Boot Slackware install media and prepare the Pkgtool session."""
    if boot_prompt:
        session.vga_wait(boot_prompt, match=Match.LINE)
        session.kb_type("\n")
    if root_prompt:
        session.vga_wait(root_prompt, match=Match.LINE)
        session.change_floppy(root_image)
        session.kb_press("ret")
    if continuation_prompt:
        session.vga_wait(continuation_prompt)
        session.kb_press("ret")
    if keyboard_prompt:
        session.vga_wait("Enter 1 to select a keyboard map:", match=Match.LINE)
        session.kb_type("\n")
    Pkgtool(session, options).install()
