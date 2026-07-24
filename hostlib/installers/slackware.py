"""Automate Slackware releases that use Pkgtool's ``setup`` program.

The guestlib dialog adapter makes setup menus observable on ``ttyS3``. One
driver covers releases from early floppy sets through CD-ROM distributions by
configuring boot/root prompts, source layout, package selection, and optional
configuration dialogs declaratively.
"""

from __future__ import annotations

import logging

from ..dialog import Answer
from ..fdisk import Fdisk
from ..session import InstallSession, Match
from ..schemas import PkgtoolInstallConfig

log = logging.getLogger(__name__)


def run_pkgtool(session: InstallSession) -> None:
    """Run a Slackware Pkgtool installation with validated configuration."""
    config = session.config.install
    assert isinstance(config, PkgtoolInstallConfig)
    boot = config.boot
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

    def __init__(
        self, session: InstallSession, config: PkgtoolInstallConfig | None = None
    ) -> None:
        """Initialize the Pkgtool driver with typed release configuration."""
        self.s = session
        config = config or session.config.install
        assert isinstance(config, PkgtoolInstallConfig)
        self.disk = config.disk
        self.locale = config.locale
        self.network = config.network
        self.prompts = config.prompts
        self.settings = config.slackware
        self.d = session.dialog

    def install(self) -> None:
        """Run the complete Slackware setup workflow."""
        self.s.vga_wait(f"{self.settings.setup_hostname} login:", match=Match.LINE)
        self.s.kb_type("root\n")
        self._prepare()
        if self.settings.install_mode:
            self._setup_step("QUICK")
            self.d.answer(Answer("menu", "CHANGE INSTALL MODE", self.settings.install_mode))
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
        o = self.disk
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
            Answer("menu", r"Slackware(96)? Linux Setup \(version .*\)", answer, regex=True)
        )

    def _swap(self) -> None:
        """Configure the target swap partition."""
        self.d.answer_until(
            Answer("yesno", "SWAP SPACE DETECTED", "yes"),
            Answer("msgbox", "MKSWAP WARNING", "ok"),
            Answer("yesno", "USE MKSWAP?", "yes"),
            Answer("yesno", "ACTIVATE SWAP SPACE?", "yes"),
            Answer("msgbox", "SWAP SPACE CONFIGURED", "ok"),
            Answer("yesno", "CONTINUE WITH INSTALLATION?", "yes", exit=True),
        )

    def _target_and_source(self) -> None:
        """Configure the target filesystem and package source."""
        if self.settings.source_before_target:
            self._select_source()
        self._select_target()
        self._mount_fat_partition()
        if not self.settings.source_before_target:
            self._select_source()

    def _select_target(self) -> None:
        """Select and format the configured Linux target partition."""
        o = self.disk
        self.d.answer_until(
            Answer("menu", "Select Linux installation partition:", o.linux_partition),
            Answer("msgbox", "Using this partition for Linux:", "ok"),
            Answer(
                "menu",
                r"(CHOOSE LINUX FILESYSTEM|SELECT FILESYSTEM FOR .*)",
                "ext2",
                regex=True,
            ),
            Answer("menu", r"FORMAT PARTITION( .*)?", "Format", regex=True),
            Answer("menu", r"SELECT INODE DENSITY( .*)?", "4096", regex=True),
            Answer("msgbox", "DONE ADDING LINUX PARTITIONS TO /etc/fstab", "ok"),
            Answer("yesno", "DOS AND OS/2 PARTITION SETUP", "yes", exit=True),
            Answer(
                "yesno",
                r"FAT/FAT32(/HPFS)? PARTITIONS DETECTED",
                "yes",
                regex=True,
                exit=True,
            ),
        )

    def _mount_fat_partition(self) -> None:
        """Add the staged FAT partition to the installed filesystem table."""
        o = self.disk
        self.d.answer_until(
            Answer("inputbox", "CHOOSE PARTITION", o.fat_partition),
            Answer("menu", "CHOOSE PARTITION", o.fat_partition),
            Answer("menu", "SELECT PARTITION TO ADD TO /etc/fstab", o.fat_partition),
            Answer("inputbox", "SELECT MOUNT POINT", o.fat_mount),
            Answer("inputbox", r"PICK MOUNT POINT FOR .*", o.fat_mount, regex=True),
            Answer("msgbox", "CURRENT DOS/HPFS PARTITION STATUS", "ok"),
            Answer("msgbox", r"DONE ADDING FAT/FAT32(/HPFS)? PARTITIONS", "ok", regex=True),
            Answer("inputbox", "CHOOSE PARTITION", "q"),
            Answer("yesno", "CONTINUE?", "yes", exit=True),
        )

    def _select_source(self) -> None:
        """Select CD-ROM, staged FAT packages, or a manually chosen source.

        CD-ROM releases expose several alternative discovery dialogs, while a
        FAT source uses the already mounted package directory. Unknown devices
        deliberately fall back to manual selection before automation resumes.
        """
        source = self.settings.source
        if source == "/dev/hdc":
            self.d.answer_until(
                Answer("menu", "SOURCE MEDIA SELECTION", "CD-ROM", description=True),
                Answer(
                    "menu",
                    "Install from the Slackware CD-ROM",
                    r"(IDE.*CD drives|ATAPI/IDE CD drives)",
                    description=True,
                    item_regex=True,
                ),
                Answer("menu", "SCAN FOR CD-ROM DRIVE?", "manual"),
                Answer("menu", "SELECT IDE DEVICE", source),
                Answer("menu", "MANUAL CD-ROM DEVICE SELECTION", source),
                Answer("yesno", r"USING CD-ROM DRIVE:.*", "no", regex=True),
                Answer("menu", "Pick your installation method", "slakware"),
                Answer("menu", "CHOOSE INSTALLATION TYPE", "slakware"),
                Answer("yesno", "CONTINUE?", "yes", exit=True),
            )
        elif source == self.disk.fat_partition:
            self.d.answer(Answer("menu", "SOURCE MEDIA SELECTION", "4"))
            self.d.answer(
                Answer(
                    "inputbox",
                    "INSTALL FROM THE CURRENT FILESYSTEM",
                    f"{self.disk.fat_mount}/packages",
                )
            )
            self.d.answer(Answer("yesno", "CONTINUE?", "yes"))
        else:
            log.warning("Manual package source selection required; automation will resume")
            self.d.answer(Answer("yesno", "CONTINUE?", "yes"))

    def _sets(self) -> None:
        """Select package series and start package installation."""
        mode = "custom path" if self.settings.tagfile_path else "default tagfiles"
        self.d.answer_until(
            Answer(
                "checklist",
                r"(PACKAGE |SOFTWARE )?SERIES SELECTION",
                self.settings.package_sets,
                regex=True,
            ),
            Answer("yesno", "CONTINUE?", "yes"),
            Answer("menu", "SELECT PROMPTING MODE", mode, description=True, exit=True),
        )
        if self.settings.tagfile_path:
            self.d.answer(
                Answer(
                    "inputbox",
                    "PROVIDE A CUSTOM PATH TO YOUR TAGFILES",
                    self.settings.tagfile_path,
                )
            )

    def _configure(self) -> None:
        """Answer boot loader, network, time-zone, and service dialogs."""
        o = self.settings
        self.d.answer_until(
            Answer("yesno", "CONFIGURE YOUR SYSTEM?", "yes"),
            Answer("menu", "MAKE BOOTDISK", "continue"),
            Answer("yesno", "MAKE BOOT DISK?", "no"),
            Answer("msgbox", "SKIPPED BOOT DISK CREATION", "ok"),
            Answer("yesno", "MODEM CONFIGURATION", "no"),
            Answer("menu", "MODEM CONFIGURATION", "no modem"),
            Answer("yesno", "MOUSE CONFIGURATION", "no"),
            Answer("menu", "MOUSE CONFIGURATION", "ps2"),
            Answer("yesno", "CONFIGURE CD-ROM?", "no"),
            Answer("yesno", "SCREEN FONT CONFIGURATION", "no"),
            Answer("yesno", "CONSOLE FONT CONFIGURATION", "no"),
            Answer("yesno", "FTAPE CONFIGURATION", "no"),
            Answer("menu", "SET YOUR MODEM SPEED", o.modem_speed),
            Answer("menu", "INSTALL LINUX KERNEL", "skip"),
            Answer("menu", "INSTALL LILO", self._lilo),
            Answer("menu", "LILO INSTALLATION", self._lilo),
            Answer("yesno", "CONFIGURE NETWORK?", self._network),
            Answer("yesno", "GPM CONFIGURATION", "no"),
            Answer("yesno", "ENABLE HOTPLUG SUBSYSTEM AT BOOT?", "no"),
            Answer("yesno", "SELECTION 1.5 CONFIGURATION", "no"),
            Answer("menu", "SENDMAIL CONFIGURATION", self._sendmail),
            Answer("menu", "HARDWARE CLOCK SET TO UTC?", "YES"),
            Answer("menu", "TIMEZONE CONFIGURATION", self._timezone),
            Answer("yesno", "WARNING: NO ROOT PASSWORD DETECTED", "no"),
            Answer("msgbox", "SETUP COMPLETE", "ok", exit=True),
        )

    def _lilo(self, title: str) -> None:
        """Configure and install LILO for the selected Slackware release."""
        o = self.settings
        if o.simple_lilo:
            self.d.answer(Answer("menu", title, "2"))
            return
        if title == "INSTALL LILO":
            self.d.answer(Answer("menu", title, "expert"))
            title = "EXPERT LILO INSTALLATION"
        self.d.answer_until(
            Answer("menu", title, "Begin"),
            Answer("inputbox", r"OPTIONAL (LILO )?append=.* LINE", "", regex=True),
            Answer("menu", "CONFIGURE LILO TO USE FRAME BUFFER CONSOLE?", o.lilo_framebuffer),
            Answer("menu", "SELECT LILO TARGET LOCATION", "MBR"),
            Answer("inputbox", "CONFIRM LOCATION TO INSTALL LILO", self.disk.target_disk),
            Answer("menu", r"CHOOSE LILO (DELAY|TIMEOUT)", "None", regex=True),
            Answer("menu", title, "Linux"),
            Answer("inputbox", "SELECT LINUX PARTITION", self.disk.linux_partition),
            Answer("inputbox", "SELECT PARTITION NAME", self.disk.linux_partition_name),
            Answer("menu", title, "Install", exit=True),
        )

    def _network(self, title: str) -> None:
        """Configure the Slackware hostname and static network settings."""
        n = self.network
        self.d.answer(Answer("yesno", title, "yes"))
        self.d.answer_until(
            Answer("msgbox", "NETWORK CONFIGURATION", ""),
            Answer("inputbox", "ENTER HOSTNAME", n.hostname),
            Answer("inputbox", r"ENTER DOMAINNAME( FOR .*)?", n.domain, regex=True),
            Answer("yesno", "LOOPBACK ONLY?", "no"),
            Answer("menu", r"SETUP IP (ADDRESS )?FOR .*", "static IP", regex=True),
            Answer("inputbox", r"ENTER (LOCAL IP ADDRESS|IP ADDRESS FOR .*)", n.ip, regex=True),
            Answer("inputbox", "ENTER NETWORK ADDRESS", n.network),
            Answer("inputbox", "ENTER BROADCAST ADDRESS", n.broadcast),
            Answer("inputbox", "ENTER GATEWAY ADDRESS", n.gateway),
            Answer("inputbox", r"ENTER NETMASK( .*)?", n.netmask, regex=True),
            Answer("yesno", "USE A NAMESERVER?", "yes"),
            Answer("inputbox", "SELECT NAMESERVER", n.nameserver),
            Answer("menu", "PROBE FOR NETWORK CARD?", "probe"),
            Answer("msgbox", "CARD DETECTED", "ok"),
            Answer("msgbox", "NETWORK SETUP COMPLETE", "ok", exit=True),
            Answer("yesno", "NETWORK SETUP COMPLETE", "yes", exit=True),
            Answer("inputmenu", "CONFIRM NETWORK SETUP", "", exit=True),
        )

    def _timezone(self, title: str) -> None:
        """Select the configured time zone and optional window manager."""
        self.d.answer(Answer("menu", title, self.locale.timezone))
        self._xwmconfig()

    def _sendmail(self, title: str) -> None:
        """Select the configured sendmail mode and optional window manager."""
        self.d.answer(Answer("menu", title, self.settings.sendmail_mode))
        self._xwmconfig()

    def _xwmconfig(self) -> None:
        """Select the default window manager when its prompt is enabled."""
        if not self.settings.xwmconfig:
            return
        try:
            self.s.vga_wait("SELECT DEFAULT WINDOW MANAGER FOR X", timeout=1)
        except TimeoutError:
            return
        self.s.kb_press("spc", "ret")
        self.settings.xwmconfig = False

    def _postinst(self) -> None:
        """Launch the staged post-installation runtime."""
        hostname = self.network.hostname
        self.s.vga_wait(f"{hostname} login:", match=Match.LINE)
        self.s.kb_type("root\n")
        self.s.vga_wait(self.prompts.postinst_prompt or f"{hostname}:~#", match=Match.LINE)
        self.s.kb_type(f"{self.disk.fat_mount}/guestlib.d/postinst.sh\n")


def boot_pkgtool(
    session: InstallSession,
    *,
    boot_prompt: str | None = "boot:",
    root_prompt: str | None = None,
    root_image: str = "root.img",
    continuation_prompt: str | None = None,
    keyboard_prompt: bool = False,
    config: PkgtoolInstallConfig | None = None,
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
    Pkgtool(session, config).install()
