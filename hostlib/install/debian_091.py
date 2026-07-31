"""Automate Debian 0.91's prompt-driven ``dinstall`` shell script."""

from __future__ import annotations

from ..config import RetroConfig
from ..schemas.debian import Debian091InstallConfig
from ..session import Match, QemuSession
from .fdisk import Fdisk
from .postinst import run_postinst


class Debian091Installer:
    """Drive the one-off Debian 0.91 installation and boot-loader setup."""

    def __init__(self, session: QemuSession, config: RetroConfig) -> None:
        """Bind the typed Debian 0.91 settings to one install session."""
        self.s = session
        self.config = config
        options = config.install
        assert isinstance(options, Debian091InstallConfig)
        self.disk = options.disk
        self.locale = options.locale
        self.network = options.network

    def prompt(self, *questions: str, answer: object = "", regex: bool = False) -> None:
        """Answer one VGA prompt, optionally matching its lines as regular expressions."""
        match = Match.REGEX if regex else Match.TEXT
        self.s.vga_wait(*questions, match=match)
        self.s.kb_type(f"{answer}\n")

    def install(self) -> None:
        """Install Debian, configure LILO, reboot, and launch post-installation."""
        self.s.boot_command("boot:")
        self.s.vga_wait("#", match=Match.LINE)
        self.s.serial_shell_start()
        Fdisk(self.s).partition_swap_root(self.disk.target_disk, self.disk.swap_mb)
        self.s.serial_shell_exit()
        self.s.kb_type("dinstall\n")
        self._install_base()
        self._configure_system()
        self._install_lilo()
        self.s.set_boot("c")
        self.s.kb_type("reboot\n")
        run_postinst(
            self.s,
            self.config,
            login=f"{self.network.hostname}.{self.network.domain} login:",
            shell="[root:~]#",
        )

    def _install_base(self) -> None:
        """Create filesystems and load the two base-system floppies."""
        root = self.disk.root_partition.removeprefix("/dev/")
        swap = self.disk.swap_partition.removeprefix("/dev/")
        self.prompt("2   Initialize and activate your swap partition(s)", answer="2")
        self.prompt("What is the name of your swap partition", answer=swap)
        self.prompt("Would you like to check for bad blocks (y/n) [y]?", answer="n")
        self.prompt("Press <RETURN> to continue...")
        self.prompt("3   Format your Linux native partition(s) with mke2fs", answer="3")
        self.prompt("On which partition do you wish to create an ext2 filesystem?", answer=root)
        self.prompt("Would you like to check for bad blocks (y/n) [y]?", answer="n")
        self.prompt("Press <RETURN> to continue...")
        self.prompt("5   Install the Debian Linux base system", answer="5")
        self.prompt("Continue with the installation of the base system (y/n) [y]?", answer="y")
        mount_prompt = (
            "(m)ount another filesystem, (u)nmount a mounted filesystem,",
            "or (c)ontinue with the installation:",
        )
        self.prompt(*mount_prompt, answer="m")
        self.prompt("Mount which filesystem (ex: /dev/hda3)? /dev/", answer=root)
        self.prompt(f"Mount /dev/{root} on which directory (ex: /usr)? /root/")
        self.prompt(*mount_prompt, answer="c")
        self.prompt("Please specify /dev/fd0 or /dev/fd1 [/dev/fd0]: /dev/", answer="fd0")

        for number in (1, 2):
            self.s.vga_wait(f"Please insert basedisk #{number} into /dev/fd0 and press <RETURN>:")
            self.s.change_floppy(f"basedsk{number}")
            self.s.kb_press("ret")

    def _configure_system(self) -> None:
        """Answer Debian's installed-system, network, locale, and device questions."""
        root = self.disk.root_partition.removeprefix("/dev/")
        swap = self.disk.swap_partition.removeprefix("/dev/")
        network = self.network
        self.prompt("Which partition contains your root filesystem? /dev/", answer=root)
        self.prompt(
            "Which partition is your swap partition (<RETURN> for none)? /dev/",
            answer=swap,
        )
        self.prompt("What is the unqualified hostname of your machine?", answer=network.hostname)
        self.prompt("What is the local domainname without the leading `.'?", answer=network.domain)
        self.prompt(
            r"Your fully-qualified hostname is .* Correct \(y/n\)?",
            answer="y",
            regex=True,
        )
        self.prompt("Does your machine require additional networking setup (y/n)?", answer="y")
        self.prompt("What is the IP address of your machine?", answer=network.ip)
        self.prompt("What is your netmask?", answer=network.netmask)
        self.prompt("What is your network address?", answer=network.network)
        self.prompt(
            "What is your broadcast address (if you don't have one, type `none')?",
            answer=network.broadcast,
        )
        self.prompt("What is your gateway address?", answer=network.gateway)
        self.prompt(
            "What is the address of your nameserver (if your machine is the name server,",
            "enter 127.0.0.1; if you don't have one, type `none')?",
            answer=network.nameserver,
        )
        self.prompt("Is this correct (y/n)?", answer="y")
        self.prompt("Do you have an ethernet connection (y/n)?", answer="y")
        self.prompt("Is your system clock set to GMT?", answer="y")
        self.prompt("Press <RETURN> for more...")
        self.prompt("Which timezone?", answer=self.locale.timezone)
        self.prompt("Load a non-US keymap at boot time (y/n)?", answer="n")
        self.prompt(
            "Which port contains your modem (if you have one)?",
            answer=5,
        )
        self.prompt(
            "Which type of mouse do you have (if you have one)?",
            answer=1,
        )
        self.prompt("Which port contains your mouse?", answer=3)
        self.prompt("What type of serial mouse do you have?", answer=1)
        self.prompt(
            "Would you like to make a custom bootdisk before proceeding (y/n)?",
            answer="n",
        )
        self.prompt("Press <RETURN> to continue...")
        self.prompt("7   Return to the shell", answer="7")

    def _install_lilo(self) -> None:
        """Install LILO into the target system from a serial shell."""
        root_device = self.disk.root_partition
        commands = (
            f"/root/usr/sbin/rdev /root/vmlinuz {root_device}",
            "/root/usr/sbin/rdev -R /root/vmlinuz 1",
            "/root/usr/sbin/rdev -v /root/vmlinuz -1",
            f'sed "s|/dev/hda3|{root_device}|g" /root/etc/lilo.conf '
            '| sed "s|read-only|#read-only|g" '
            '| sed "s|delay=20|#delay=20|g" >/root/tmp/lilo.conf',
            "mv /root/tmp/lilo.conf /root/etc/lilo.conf",
            "/root/sbin/lilo -r /root -C /etc/lilo.conf",
        )
        self.s.vga_wait("#", match=Match.LINE)
        self.s.serial_shell_start()
        for command in commands:
            self.s.serial_shell_send(command)
        self.s.serial_shell_exit()


def run_debian_091(session: QemuSession, config: RetroConfig) -> None:
    """Run Debian 0.91's dedicated installer."""
    Debian091Installer(session, config).install()
