"""Automate Slackware releases that use Pkgtool's ``setup`` program.

The guestlib dialog adapter makes setup menus observable on ``ttyS3``. One
driver covers releases from early floppy sets through CD-ROM distributions by
selecting a named Python workflow profile. Source layout and package selection
remain declarative.
"""

from __future__ import annotations

from dataclasses import dataclass
import logging

from ..config import RetroConfig
from ..schemas.slackware import SlackwareDialogInstallConfig
from ..session import Match, QemuSession
from .dialog import AnswerTitle, Dialog
from .fdisk import Fdisk
from .postinst import fat_mount_command

log = logging.getLogger(__name__)


@dataclass(frozen=True)
class SlackwareDialogVariant:
    """Describe one release's fixed boot and setup screen sequence."""

    boot_prompt: str | None = "boot:"
    root_prompt: str | None = None
    continuation_prompt: str | None = None
    keyboard_prompt: bool = False
    setup_hostname: str = "slackware"
    install_mode: str | None = None
    source_before_target: bool = False
    simple_lilo: bool = False
    xwmconfig: bool = False


VARIANT_112 = SlackwareDialogVariant(
    boot_prompt=None,
    root_prompt="Please remove the boot kernel disk from your floppy drive,",
    continuation_prompt="VFS: Insert root floppy and press ENTER",
    setup_hostname="darkstar",
    source_before_target=True,
    simple_lilo=True,
)
VARIANT_20 = SlackwareDialogVariant(
    root_prompt="Please remove the boot kernel disk from your floppy drive, insert a",
    continuation_prompt="VFS: Insert root floppy and press ENTER",
)
VARIANT_21 = SlackwareDialogVariant(
    root_prompt="Please remove the boot kernel disk from your floppy drive, insert a",
)
VARIANT_22 = SlackwareDialogVariant(root_prompt="VFS: Insert ramdisk floppy and press ENTER")
VARIANT_30 = SlackwareDialogVariant(
    root_prompt="VFS: Insert ramdisk floppy and press ENTER",
    install_mode="VERBOSE",
)
VARIANT_31 = SlackwareDialogVariant(
    root_prompt="VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER"
)
VARIANT_35 = SlackwareDialogVariant()
VARIANT_70 = SlackwareDialogVariant(xwmconfig=True)
VARIANT_80 = SlackwareDialogVariant(keyboard_prompt=True, xwmconfig=True)

VARIANTS = {
    "1.1.2": VARIANT_112,
    "2.0": VARIANT_20,
    "2.1": VARIANT_21,
    "2.2-2.3": VARIANT_22,
    "3.0": VARIANT_30,
    "3.1-3.4": VARIANT_31,
    "3.5-4.0": VARIANT_35,
    "7.0-7.1": VARIANT_70,
    "8.0-9.0": VARIANT_80,
}


def run_slackware_dialog(session: QemuSession, config: RetroConfig) -> None:
    """Run the configured Slackware dialog installer variant."""
    options = config.install
    assert isinstance(options, SlackwareDialogInstallConfig)
    variant = VARIANTS[options.variant]
    if variant.boot_prompt:
        session.boot_command(variant.boot_prompt)
    if variant.root_prompt:
        session.vga_wait(variant.root_prompt, match=Match.LINE)
        session.change_floppy("root.img")
        session.kb_press("ret")
    if variant.continuation_prompt:
        session.vga_wait(variant.continuation_prompt)
        session.kb_press("ret")
    if variant.keyboard_prompt:
        session.vga_wait("Enter 1 to select a keyboard map:", match=Match.LINE)
        session.kb_type("\n")
    DialogInstaller(session, config, variant).install()


class DialogInstaller:
    """Drive Slackware setup and Pkgtool dialogs through guestlib.

    Setup stages are selected from the visible menu, while dialog choices are
    matched structurally. Optional configuration screens are handled as an
    unordered choice set to tolerate release-dependent omissions.
    """

    def __init__(
        self,
        session: QemuSession,
        config: RetroConfig,
        variant: SlackwareDialogVariant,
        dialog: Dialog | None = None,
    ) -> None:
        """Initialize the dialog driver with typed release configuration."""
        self.s = session
        options = config.install
        assert isinstance(options, SlackwareDialogInstallConfig)
        self.disk = options.disk
        self.locale = options.locale
        self.network = options.network
        self.prompts = options.prompts
        self.packages = options.packages
        self.bootloader = options.bootloader
        self.modem = options.modem
        self.mail = options.mail
        self.variant = variant
        self.xwmconfig_pending = variant.xwmconfig
        self.d = dialog if dialog is not None else Dialog(session.serial)

    def install(self) -> None:
        """Run the complete Slackware setup workflow."""
        self.s.vga_wait(f"{self.variant.setup_hostname} login:", match=Match.LINE)
        self.s.kb_type("root\n")
        self._prepare()
        if self.variant.install_mode:
            self._setup_step("QUICK")
            self.d.answer(AnswerTitle("menu", "CHANGE INSTALL MODE", self.variant.install_mode))
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
        shell_prompt = r"# *$"
        self.s.serial_shell_start(screen_prompt=shell_prompt, screen_match=Match.REGEX)
        for command in (
            fat_mount_command(
                o.fat_mount,
                o.fat_partition,
                o.fat_filesystem,
            ),
            "rm /bin/dialog",
            f"cp {o.fat_mount}/guestlib.d/dialog.sh /bin/dialog",
        ):
            self.s.serial_shell_send(command)
        Fdisk(self.s).partition_swap_root(o.target_disk, o.swap_mb)
        self.s.serial_shell_exit(screen_prompt=shell_prompt, screen_match=Match.REGEX)
        self.s.kb_type("setup\n")

    def _setup_step(self, answer: str) -> None:
        """Select one item from the Slackware setup menu."""
        self.d.answer(
            AnswerTitle("menu", r"Slackware(96)? Linux Setup \(version .*\)", answer, regex=True)
        )

    def _swap(self) -> None:
        """Configure the target swap partition."""
        self.d.answer_until(
            AnswerTitle("yesno", "SWAP SPACE DETECTED", "yes"),
            AnswerTitle("msgbox", "MKSWAP WARNING", "ok"),
            AnswerTitle("yesno", "USE MKSWAP?", "yes"),
            AnswerTitle("yesno", "ACTIVATE SWAP SPACE?", "yes"),
            AnswerTitle("msgbox", "SWAP SPACE CONFIGURED", "ok"),
            AnswerTitle("yesno", "CONTINUE WITH INSTALLATION?", "yes", exit=True),
        )

    def _target_and_source(self) -> None:
        """Configure the target filesystem and package source."""
        if self.variant.source_before_target:
            self._select_source()
        self._select_target()
        self._mount_fat_partition()
        if not self.variant.source_before_target:
            self._select_source()

    def _select_target(self) -> None:
        """Select and format the configured Linux target partition."""
        o = self.disk
        self.d.answer_until(
            AnswerTitle("menu", "Select Linux installation partition:", o.root_partition),
            AnswerTitle("msgbox", "Using this partition for Linux:", "ok"),
            AnswerTitle(
                "menu",
                r"(CHOOSE LINUX FILESYSTEM|SELECT FILESYSTEM FOR .*)",
                "ext2",
                regex=True,
            ),
            AnswerTitle("menu", r"FORMAT PARTITION( .*)?", "Format", regex=True),
            AnswerTitle("menu", r"SELECT INODE DENSITY( .*)?", "4096", regex=True),
            AnswerTitle("msgbox", "DONE ADDING LINUX PARTITIONS TO /etc/fstab", "ok"),
            AnswerTitle("yesno", "DOS AND OS/2 PARTITION SETUP", "yes", exit=True),
            AnswerTitle(
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
            AnswerTitle("inputbox", "CHOOSE PARTITION", o.fat_partition),
            AnswerTitle("menu", "CHOOSE PARTITION", o.fat_partition),
            AnswerTitle("menu", "SELECT PARTITION TO ADD TO /etc/fstab", o.fat_partition),
            AnswerTitle("inputbox", "SELECT MOUNT POINT", o.fat_mount),
            AnswerTitle("inputbox", r"PICK MOUNT POINT FOR .*", o.fat_mount, regex=True),
            AnswerTitle("msgbox", "CURRENT DOS/HPFS PARTITION STATUS", "ok"),
            AnswerTitle("msgbox", r"DONE ADDING FAT/FAT32(/HPFS)? PARTITIONS", "ok", regex=True),
            AnswerTitle("inputbox", "CHOOSE PARTITION", "q"),
            AnswerTitle("yesno", "CONTINUE?", "yes", exit=True),
        )

    def _select_source(self) -> None:
        """Select CD-ROM, staged FAT packages, or a manually chosen source.

        CD-ROM releases expose several alternative discovery dialogs, while a
        FAT source uses the already mounted package directory. Unknown devices
        deliberately fall back to manual selection before automation resumes.
        """
        source = self.packages.source
        if source == "/dev/hdc":
            self.d.answer_until(
                AnswerTitle("menu", "SOURCE MEDIA SELECTION", "CD-ROM", description=True),
                AnswerTitle(
                    "menu",
                    "Install from the Slackware CD-ROM",
                    r"(IDE.*CD drives|ATAPI/IDE CD drives)",
                    description=True,
                    item_regex=True,
                ),
                AnswerTitle("menu", "SCAN FOR CD-ROM DRIVE?", "manual"),
                AnswerTitle("menu", "SELECT IDE DEVICE", source),
                AnswerTitle("menu", "MANUAL CD-ROM DEVICE SELECTION", source),
                AnswerTitle("yesno", r"USING CD-ROM DRIVE:.*", "no", regex=True),
                AnswerTitle("menu", "Pick your installation method", "slakware"),
                AnswerTitle("menu", "CHOOSE INSTALLATION TYPE", "slakware"),
                AnswerTitle("yesno", "CONTINUE?", "yes", exit=True),
            )
        elif source == self.disk.fat_partition:
            self.d.answer(AnswerTitle("menu", "SOURCE MEDIA SELECTION", "4"))
            self.d.answer(
                AnswerTitle(
                    "inputbox",
                    "INSTALL FROM THE CURRENT FILESYSTEM",
                    f"{self.disk.fat_mount}/packages",
                )
            )
            self.d.answer(AnswerTitle("yesno", "CONTINUE?", "yes"))
        else:
            log.warning("Manual package source selection required; automation will resume")
            self.d.answer(AnswerTitle("yesno", "CONTINUE?", "yes"))

    def _sets(self) -> None:
        """Select package series and start package installation."""
        mode = "custom path" if self.packages.tagfile_path else "default tagfiles"
        self.d.answer_until(
            AnswerTitle(
                "checklist",
                r"(PACKAGE |SOFTWARE )?SERIES SELECTION",
                self.packages.package_sets,
                regex=True,
            ),
            AnswerTitle("yesno", "CONTINUE?", "yes"),
            AnswerTitle("menu", "SELECT PROMPTING MODE", mode, description=True, exit=True),
        )
        if self.packages.tagfile_path:
            self.d.answer(
                AnswerTitle(
                    "inputbox",
                    "PROVIDE A CUSTOM PATH TO YOUR TAGFILES",
                    self.packages.tagfile_path,
                )
            )

    def _configure(self) -> None:
        """Answer boot loader, network, time-zone, and service dialogs."""
        self.d.answer_until(
            AnswerTitle("yesno", "CONFIGURE YOUR SYSTEM?", "yes"),
            AnswerTitle("menu", "MAKE BOOTDISK", "continue"),
            AnswerTitle("yesno", "MAKE BOOT DISK?", "no"),
            AnswerTitle("msgbox", "SKIPPED BOOT DISK CREATION", "ok"),
            AnswerTitle("yesno", "MODEM CONFIGURATION", "no"),
            AnswerTitle("menu", "MODEM CONFIGURATION", "no modem"),
            AnswerTitle("yesno", "MOUSE CONFIGURATION", "no"),
            AnswerTitle("menu", "MOUSE CONFIGURATION", "ps2"),
            AnswerTitle("yesno", "CONFIGURE CD-ROM?", "no"),
            AnswerTitle("yesno", "SCREEN FONT CONFIGURATION", "no"),
            AnswerTitle("yesno", "CONSOLE FONT CONFIGURATION", "no"),
            AnswerTitle("yesno", "FTAPE CONFIGURATION", "no"),
            AnswerTitle("menu", "SET YOUR MODEM SPEED", self.modem.speed),
            AnswerTitle("menu", "INSTALL LINUX KERNEL", "skip"),
            AnswerTitle("menu", "INSTALL LILO", self._lilo),
            AnswerTitle("menu", "LILO INSTALLATION", self._lilo),
            AnswerTitle("yesno", "CONFIGURE NETWORK?", self._network),
            AnswerTitle("yesno", "GPM CONFIGURATION", "no"),
            AnswerTitle("yesno", "ENABLE HOTPLUG SUBSYSTEM AT BOOT?", "no"),
            AnswerTitle("yesno", "SELECTION 1.5 CONFIGURATION", "no"),
            AnswerTitle("menu", "SENDMAIL CONFIGURATION", self._sendmail),
            AnswerTitle("menu", "HARDWARE CLOCK SET TO UTC?", "YES"),
            AnswerTitle("menu", "TIMEZONE CONFIGURATION", self._timezone),
            AnswerTitle("yesno", "WARNING: NO ROOT PASSWORD DETECTED", "no"),
            AnswerTitle("msgbox", "SETUP COMPLETE", "ok", exit=True),
        )

    def _lilo(self, title: str) -> None:
        """Configure and install LILO for the selected Slackware release."""
        if self.variant.simple_lilo:
            self.d.answer(AnswerTitle("menu", title, "2"))
            return
        if title == "INSTALL LILO":
            self.d.answer(AnswerTitle("menu", title, "expert"))
            title = "EXPERT LILO INSTALLATION"
        self.d.answer_until(
            AnswerTitle("menu", title, "Begin"),
            AnswerTitle("inputbox", r"OPTIONAL (LILO )?append=.* LINE", "", regex=True),
            AnswerTitle(
                "menu",
                "CONFIGURE LILO TO USE FRAME BUFFER CONSOLE?",
                self.bootloader.framebuffer,
            ),
            AnswerTitle("menu", "SELECT LILO TARGET LOCATION", "MBR"),
            AnswerTitle("inputbox", "CONFIRM LOCATION TO INSTALL LILO", self.disk.target_disk),
            AnswerTitle("menu", r"CHOOSE LILO (DELAY|TIMEOUT)", "None", regex=True),
            AnswerTitle("menu", title, "Linux"),
            AnswerTitle("inputbox", "SELECT LINUX PARTITION", self.disk.root_partition),
            AnswerTitle("inputbox", "SELECT PARTITION NAME", self.bootloader.label),
            AnswerTitle("menu", title, "Install", exit=True),
        )

    def _network(self, title: str) -> None:
        """Configure the Slackware hostname and static network settings."""
        n = self.network
        self.d.answer(AnswerTitle("yesno", title, "yes"))
        self.d.answer_until(
            AnswerTitle("msgbox", "NETWORK CONFIGURATION", ""),
            AnswerTitle("inputbox", "ENTER HOSTNAME", n.hostname),
            AnswerTitle("inputbox", r"ENTER DOMAINNAME( FOR .*)?", n.domain, regex=True),
            AnswerTitle("yesno", "LOOPBACK ONLY?", "no"),
            AnswerTitle("menu", r"SETUP IP (ADDRESS )?FOR .*", "static IP", regex=True),
            AnswerTitle(
                "inputbox", r"ENTER (LOCAL IP ADDRESS|IP ADDRESS FOR .*)", n.ip, regex=True
            ),
            AnswerTitle("inputbox", "ENTER NETWORK ADDRESS", n.network),
            AnswerTitle("inputbox", "ENTER BROADCAST ADDRESS", n.broadcast),
            AnswerTitle("inputbox", "ENTER GATEWAY ADDRESS", n.gateway),
            AnswerTitle("inputbox", r"ENTER NETMASK( .*)?", n.netmask, regex=True),
            AnswerTitle("yesno", "USE A NAMESERVER?", "yes"),
            AnswerTitle("inputbox", "SELECT NAMESERVER", n.nameserver),
            AnswerTitle("menu", "PROBE FOR NETWORK CARD?", "probe"),
            AnswerTitle("msgbox", "CARD DETECTED", "ok"),
            AnswerTitle("msgbox", "NETWORK SETUP COMPLETE", "ok", exit=True),
            AnswerTitle("yesno", "NETWORK SETUP COMPLETE", "yes", exit=True),
            AnswerTitle("inputmenu", "CONFIRM NETWORK SETUP", "", exit=True),
        )

    def _timezone(self, title: str) -> None:
        """Select the configured time zone and optional window manager."""
        self.d.answer(AnswerTitle("menu", title, self.locale.timezone))
        self._xwmconfig()

    def _sendmail(self, title: str) -> None:
        """Select the configured sendmail mode and optional window manager."""
        self.d.answer(AnswerTitle("menu", title, self.mail.mode))
        self._xwmconfig()

    def _xwmconfig(self) -> None:
        """Select the default window manager when its prompt is enabled."""
        if not self.xwmconfig_pending:
            return
        try:
            self.s.vga_wait("SELECT DEFAULT WINDOW MANAGER FOR X", timeout=1)
        except TimeoutError:
            return
        self.s.kb_press("spc", "ret")
        self.xwmconfig_pending = False

    def _postinst(self) -> None:
        """Launch the staged post-installation runtime."""
        hostname = self.network.hostname
        self.s.vga_wait(f"{hostname} login:", match=Match.LINE)
        self.s.kb_type("root\n")
        self.s.vga_wait(self.prompts.postinst_prompt or f"{hostname}:~#", match=Match.LINE)
        self.s.kb_type(f"{self.disk.fat_mount}/guestlib.d/postinst.sh\n")
