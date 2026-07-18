"""Automate Red Hat releases that use the full-screen C installer driver.

Red Hat 4.x and 5.x share broad phases but differ substantially in partition,
component, mouse, and X11 screens. ``flow`` selects the bounded branch while
network and completion behavior remain common. Kickstart-based releases use
the smaller unattended entry point in this module.
"""

from __future__ import annotations

import time

from pydantic import Field

from ..fdisk import Fdisk
from ..session import InstallSession, Match
from ..errors import ConfigError
from ..schemas import ConfigModel, NetworkConfig


class CInstallerOptions(ConfigModel):
    """Configure Red Hat C-installer automation.

    Prompt flags describe screens present in particular releases; flow and
    navigation offsets handle larger layout changes. Remaining fields supply
    boot, account, and static network answers.
    """

    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    fat_mount: str = "/retro"
    boot_prompt: str = "boot:"
    boot_command: str = ""
    boot_sleep: float = 0
    color_prompt: bool = True
    language_prompt: bool = False
    keyboard_early: bool = False
    keyboard_after_packages: bool = False
    keyboard_late: bool = False
    pcmcia_prompt: bool = True
    cdrom_type_prompt: bool = True
    insert_cd_prompt: str = "Insert your Red Hat CD into your CD drive"
    flow: str = "4x"
    x_card_down: int = 66
    monitor_key: str = "ret"
    timezone_prompt: str = "Configure Timezone"
    lilo_extra_f12: int = 0
    bootdisk_prompt: bool = False
    password: str = "password"
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="redhat"))


def run_c_installer(session: InstallSession) -> None:
    """Run a Red Hat C-installer installation with resolved options."""
    installer = CInstaller(session)
    installer.start()
    _run_c_flow(installer)
    installer.network()
    installer.finish()


def _run_c_flow(installer: "CInstaller") -> None:
    """Dispatch the release-specific middle phases of the C installer."""
    flow = installer.o.flow
    if flow == "4x":
        installer.partition_4x()
        installer.components_40()
        installer.finish_components()
        installer.x11_4x()
    elif flow == "42":
        installer._flow_42()
    elif flow in {"50", "51"}:
        installer._flow_5x()
    else:
        raise ConfigError(f"Unknown Red Hat C installer flow: {flow}")


def run_unattended(session: InstallSession) -> None:
    """Wait for an unattended Red Hat install and complete post-install setup."""
    settings = session.config.unattended_install
    session.vga_wait(settings.boot.prompt, match=Match.LINE)
    session.kb_type(settings.boot.command + "\n")
    session.vga_wait(settings.completion.prompt)
    if settings.completion.reboot:
        session.set_boot(settings.completion.boot_device)
        session.kb_type("\n")
    if settings.completion.postinst:
        session.run_postinst(
            settings.accounts.root_password,
            login=settings.prompts.login_prompt,
            shell=settings.prompts.shell_prompt,
        )


class CInstaller:
    """Drive reusable phases of Red Hat's C-installer screens.

    The top-level entry point selects a release flow, then composes these phase
    methods. Keyboard movement is explicit because these installers do not emit
    the guestlib dialog protocol.
    """

    def __init__(self, session: InstallSession, options: CInstallerOptions | None = None) -> None:
        """Initialize the C-installer driver for one Red Hat release."""
        self.s = session
        self.o = options if options is not None else session.options(CInstallerOptions)

    def step(self, screen: str, *keys: str) -> None:
        """Wait for a screen heading and send the associated key sequence."""
        self.s.vga_wait(screen)
        self.s.kb_press(*keys)

    def _flow_42(self) -> None:
        """Run the Red Hat 4.2 component-selection variant."""
        self.partition_4x()
        self.s.vga_wait("Components to Install")
        self.s.kb_press("spc")
        self.s.kb_repeat("down", 2)
        self.s.kb_press("spc", "down", "spc", "down", "spc")
        self.s.kb_repeat("down", 9)
        for _ in range(4):
            self.s.kb_press("spc", "down")
        self.s.kb_press("spc")
        self.s.kb_repeat("down", 7)
        self.s.kb_press("spc", "f12")
        self.finish_components()
        self.x11_4x()

    def _flow_5x(self) -> None:
        """Run the Red Hat 5.0 or 5.1 partition and X11 phases."""
        flow = self.o.flow
        self.s.vga_wait("Which tool would you like to use?" if flow == "50" else "Disk Setup")
        self.s.kb_press("tab", "ret")
        self.s.vga_wait("Partition Disks")
        self.partition_helper()
        self.step("Partition Disks", "ret")
        self._partition_5x(flow)
        self.components_default()
        self.finish_components()
        self.step("Probing found a PS/2 mouse", "f12")
        self.step("Emulate Three Buttons" if flow == "50" else "Configure Mouse", "f12")
        self.x11_5x()

    def _partition_5x(self, flow: str) -> None:
        """Complete release-specific root and format screens for Red Hat 5.x."""
        if flow == "50":
            self.step("Select Root Partition", "ret")
            self.step("Partition Disk", "f12")
            self.step("Active Swap Space", "f12")
            self.step("Format Partitions", "spc", "f12")
            return
        self.step("Current Disk Partitions", "down", "ret")
        self.s.kb_type("/\n")
        self.s.kb_press("f12")
        self.step("Active Swap Space", "f12")
        self.step("Partitions To Format", "spc", "f12")

    def start(self) -> None:
        """Complete the initial language, media, and install-mode screens."""
        o = self.o
        self.s.vga_wait(o.boot_prompt, match=Match.LINE)
        self.s.kb_type(f"{o.boot_command}\n")
        if o.boot_sleep:
            time.sleep(o.boot_sleep)
        if o.color_prompt:
            self.step("Are you using a color monitor?", "f12")
        self.step("Welcome to Red Hat Linux!", "f12")
        if o.language_prompt:
            self.step("Choose a Language", "f12")
        if o.keyboard_early:
            self.step("Keyboard Type", "f12")
        if o.pcmcia_prompt:
            self.step("Do you need PCMCIA support?", "f12")
        self.step("Installation Method", "f12")
        self.step(o.insert_cd_prompt, "f12")
        if o.cdrom_type_prompt:
            self.step("What type of CDROM do you have?", "f12")
        self.step("Installation Path", "f12")
        self.step("Do you have any SCSI adapters?", "f12")

    def partition_helper(self) -> None:
        """Run the early graphical partition helper workflow."""
        self.s.kb_press("alt-f2")
        self.s.serial_shell_start(screen_prompt="bash#")
        Fdisk(self.s).partition_swap_root(self.o.target_disk, self.o.swap_mb)
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit(screen_prompt="bash#")
        self.s.kb_press("alt-f1")

    def partition_4x(self) -> None:
        """Partition a Red Hat 4.x target through Disk Druid."""
        self.s.vga_wait("Partition Disks")
        self.partition_helper()
        self.step("Partition Disks", "f12")
        self.step("Active Swap Space", "f12")
        self.step("Select Root Partition", "f12")
        self.step("You may now mount other partitions within your filesystem.", "down", "ret")
        self.s.vga_wait("Edit Mount Point")
        self.s.kb_type(f"{self.o.fat_mount}\n")
        self.s.kb_press("f12")
        self.step("Format Partitions", "spc", "f12")

    def components_40(self) -> None:
        """Select Red Hat 4.0 component groups."""
        self.s.vga_wait("Components to Install")
        self.s.kb_press("spc")
        self.s.kb_repeat("down", 2)
        self.s.kb_press("spc", "down", "spc")
        self.s.kb_repeat("down", 8)
        self.s.kb_press("spc", "down", "spc", "down", "spc", "down", "spc", "down", "spc")
        self.s.kb_repeat("down", 5)
        self.s.kb_press("spc", "f12")

    def components_default(self) -> None:
        """Accept the default component selection."""
        self.step("Components to Install", "f12")

    def finish_components(self) -> None:
        """Finish component selection and begin package installation."""
        self.step("Install log", "f12")
        if self.o.keyboard_after_packages:
            self.step("Configure Keyboard", "f12")

    def x11_4x(self) -> None:
        """Configure X11 screens used by Red Hat 4.x."""
        self.step("Configure Mouse", "down", "down", "f12")
        self.s.vga_wait("Choose A Card")
        self.s.kb_repeat("down", self.o.x_card_down)
        self.s.kb_press("f12")
        self.step("Monitor Setup", "down", self.o.monitor_key)
        self.s.vga_wait("Video Memory")
        self.s.kb_repeat("down", 4)
        self.s.kb_press("f12")
        self.step("Clockchip Configuration", "f12")
        self.step("Select Video Modes", "f12")

    def x11_5x(self) -> None:
        """Configure X11 screens used by Red Hat 5.x."""
        self.step("X Server : SVGA", "f12")
        self.step("Monitor Setup", "down", "f12")
        self.step("Screen Configuration", "f12")
        self.s.vga_wait("Video Memory")
        self.s.kb_repeat("down", 4)
        self.s.kb_press("f12")
        self.step("Clockchip Configuration", "f12")
        self.step("Select Video Modes", "f12")

    def network(self) -> None:
        """Configure Red Hat networking and resolver settings."""
        o = self.o
        n = o.network
        self.step("Network Configuration", "f12")
        if o.flow == "51":
            self.step("Digital 21040 (Tulip)", "f12")
            self.step("Boot Protocol", "f12")
        self.s.vga_wait("Configure TCP/IP")
        self.s.kb_type(f"{n.ip}\n")
        for value in (n.netmask, n.network, n.broadcast):
            self.s.kb_repeat("backspace", 15)
            self.s.kb_type(f"{value}\n")
        self.s.kb_press("f12")
        self.s.vga_wait("Configure Network")
        self.s.kb_type(f"{n.domain}\n")
        self.s.kb_type(f"{n.hostname}\n")
        for value in (n.gateway, n.nameserver):
            self.s.kb_repeat("backspace", 15)
            self.s.kb_type(f"{value}\n")
        self.s.kb_press("f12")

    def finish(self) -> None:
        """Complete installation and launch post-installation setup."""
        o = self.o
        hostname = o.network.hostname
        self._finish_configuration()
        self._install_lilo()
        self.s.vga_wait("Congratulations, installation is complete.")
        self.s.set_boot("c")
        self.s.kb_press("ret")
        self.s.run_postinst(
            o.password,
            login=f"{hostname} login:",
            shell=f"[root@{hostname} /root]#",
        )

    def _finish_configuration(self) -> None:
        """Answer final service, printer, account, and boot-disk screens."""
        o = self.o
        self.step(o.timezone_prompt, "f12")
        if o.keyboard_late:
            self.step("Configure Keyboard", "f12")
        if o.flow in {"50", "51"}:
            self.step("Services", "f12")
        if o.flow == "42":
            self.step("Add Printers", "tab", "ret")
        elif o.flow in {"50", "51"}:
            self.step("Configure Printer", "tab", "ret")
        self.s.vga_wait("Root Password")
        self.s.kb_type(f"{o.password}\n")
        self.s.kb_type(f"{o.password}\n")
        self.s.kb_press("f12")
        if o.bootdisk_prompt:
            self.step("Bootdisk", "tab", "ret")

    def _install_lilo(self) -> None:
        """Install LILO and name the selected bootable partition."""
        o = self.o
        self.s.vga_wait("Lilo Installation")
        self.s.kb_press("f12", *("f12" for _ in range(o.lilo_extra_f12)))
        self.step("Bootable Partitions", "down", "ret")
        self.s.kb_repeat("backspace", 3)
        self.s.kb_press("ret", "f12")
