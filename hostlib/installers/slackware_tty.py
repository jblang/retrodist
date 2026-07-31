"""Automate Slackware 1.1.1's serial prompt-driven setup program."""

from __future__ import annotations

from ..fdisk import Fdisk
from ..schemas import SlackwareTtyInstallConfig
from ..session import InstallSession, Match


class SlackwareTtyInstaller:
    """Drive the one-off Slackware 1.1.1 tty installer."""

    def __init__(self, session: InstallSession) -> None:
        """Bind the typed Slackware tty settings to one install session."""
        self.s = session
        config = session.config.install
        assert isinstance(config, SlackwareTtyInstallConfig)
        self.disk = config.disk
        self.locale = config.locale
        self.network = config.network
        self.packages = config.packages

    def prompt(self, *questions: str, answer: str = "") -> None:
        """Answer one prompt on the installer automation serial port."""
        self.s.serial.prompt(*questions, answer=answer)

    def install(self) -> None:
        """Install Slackware, reboot, and launch staged post-installation."""
        disk = self.disk
        network = self.network
        self.s.vga_wait(f"{network.hostname} login:", match=Match.LINE)
        self.s.kb_type("root\n")
        self.s.serial_shell_start()
        Fdisk(self.s).partition_swap_root(disk.target_disk, disk.swap_mb)
        self.s.serial_console_echo(
            "Starting Slackware setup; package installation may take a while..."
        )
        self.s.serial_shell_send("setup", wait=False)
        self._configure_filesystems()
        self._install_packages()
        self._configure_system()
        self.s.serial.wait(
            "You may now reboot your computer by pressing control+alt+delete.",
            line=True,
        )
        self.s.set_boot("c")
        self.s.kb_press("ctrl-alt-delete")
        self.s.run_postinst(
            login=f"{network.hostname} login:",
            shell=f"{network.hostname}:~#",
        )

    def _configure_filesystems(self) -> None:
        """Configure swap, root, and the FAT package exchange disk."""
        fat = self.disk.fat_partition
        self.prompt(
            "Would you like to remap your keyboard?",
            "1 - yes",
            "2 - no",
            "Your choice (1/2)?",
            answer="2",
        )
        self.prompt(
            "Do you wish to install this partition as your swapspace ([y]es, [n]o)?",
            answer="y",
        )
        self.prompt(
            "Do you want setup to use mkswap on your swap partitions ([y]es, [n]o)?",
            answer="y",
        )
        self.prompt(
            "Would you like to [a]dd more software, or [i]nstall from scratch?",
            answer="i",
        )
        self.prompt(
            "What filesystem do you have (or do you plan to use) on your root",
            f"partition ({self.disk.root_partition} ), [e]xt2fs or [x]iafs?",
            answer="e",
        )
        self.prompt("Enter [i] again to install from scratch, or [a] to add", answer="i")
        self.prompt(
            "Would you like to format this partition ([y]es, [n]o, [c]heck sectors too)?",
            answer="y",
        )
        self.prompt(
            "Would you like to set up some of these partitions to be visible",
            "from Linux ([y]es, [n]o)?",
            answer="y",
        )
        self.prompt(
            "Please enter the partition you would like to access from Linux, or",
            "type <q> to quit adding new partitions:",
            answer=fat,
        )
        self.prompt(f"Where would you like to mount {fat}?", answer=self.disk.fat_mount)
        self.prompt(f"Done adding partition {fat}.", answer="q")

    def _install_packages(self) -> None:
        """Select the FAT package source and requested Slackware disk sets."""
        self.prompt("1 -- Install from a hard drive partition.", answer="1")
        self.prompt(
            "Please enter the partition where the Slackware sources can be",
            "found, or [p] to see a partition list:",
            answer=self.disk.fat_partition,
        )
        self.prompt("What directory are the Slackware sources in?", answer="/packages")
        self.prompt(
            "What type of filesystem does your Slackware source partition contain?",
            answer="1",
        )
        self.prompt("Which disk sets do you want to install?", answer=self.packages.package_sets)
        self.prompt("Do you want to use PROMPT mode (y/n)?", answer="y")

    def _configure_system(self) -> None:
        """Configure booting, networking, console selection, and timezone."""
        network = self.network
        self.prompt(
            "It is recommended that you make a boot disk.",
            "Would you like to do this ([y]es, [n]o)?",
            answer="n",
        )
        self.prompt("Would you like to set up your modem ([y]es, [n]o)?", answer="n")
        self.prompt("Would you like to set up your mouse ([y]es, [n]o)?", answer="n")
        self.prompt(
            "LILO (Linux Loader) Installation:",
            "Which option would you like? (1/2/3/4):",
            answer="2",
        )
        self.prompt("Would you like to configure your network ([y]es, [n]o)?", answer="y")
        self.prompt("Enter hostname:", answer=network.hostname)
        self.prompt(f"Enter domain name for {network.hostname}:", answer=network.domain)
        self.prompt("Do you plan to ONLY use loopback ([y]es, [n]o)?", answer="n")
        self.prompt(
            f"Enter IP address for {network.hostname} (aaa.bbb.ccc.ddd):",
            answer=network.ip,
        )
        self.prompt("Enter network address (aaa.bbb.ccc.ddd):", answer=network.network)
        self.prompt("Enter gateway address (aaa.bbb.ccc.ddd):", answer=network.gateway)
        self.prompt("Enter netmask (aaa.bbb.ccc.ddd):", answer=network.netmask)
        self.prompt("Enter broadcast address (aaa.bbb.ccc.ddd):", answer=network.broadcast)
        self.prompt(
            f"Name Server for domain {network.domain} (aaa.bbb.ccc.ddd):",
            answer=network.nameserver,
        )
        self.prompt(
            'Would you like to add "selection -t none &" to /etc/rc.d/rc.local so that',
            "selection will load at boot time ([y]es, [n]o)?",
            answer="n",
        )
        self.prompt("Would you like to configure your timezone ([y]es, [n]o)?", answer="y")
        self.prompt(
            "Select one of these timezones:",
            "Timezone?",
            answer=self.locale.timezone,
        )


def run_slackware_tty(session: InstallSession) -> None:
    """Run Slackware 1.1.1's dedicated tty installer."""
    SlackwareTtyInstaller(session).install()
