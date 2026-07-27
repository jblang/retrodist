"""Automate Red Hat releases that use the full-screen C installer driver.

Red Hat 4.x and 5.x share broad phases but differ substantially in partition,
component, mouse, and X11 screens. ``flow`` selects the bounded branch while
network and completion behavior remain common. Kickstart-based releases use
the smaller unattended entry point in this module.
"""

from __future__ import annotations

import time

from ..fdisk import Fdisk
from ..session import InstallSession, Match
from ..newt_dialog import NewtDialog
from ..errors import ConfigError
from ..schemas import CInstallConfig, UnattendedInstallConfig


# Red Hat 4.0's ``RedHat/base/comps`` and ``misc/src/install/pkgs.c`` define
# these rendered component names and their initially selected skeleton state.
COMPONENTS_40 = {
    "C Development": True,
    "C++ Development": True,
    "Print Server": True,
    "Game Machine": True,
    "Multimedia Machine": True,
    "X Window System": True,
    "X Development": True,
    "X multimedia support": True,
    "Extra Documentation": True,
}

COMPONENTS_42 = {
    "C Development": True,
    "C++ Development": True,
    "Printer Support": True,
    "Dialup Workstation": True,
    "Game Machine": True,
    "Multimedia Machine": True,
    "X Window System": True,
    "X Development": True,
}


def run_c_installer(session: InstallSession) -> None:
    """Run a Red Hat C-installer installation with validated configuration."""
    installer = CInstaller(session)
    installer.start()
    _run_c_flow(installer)
    installer.network()
    installer.finish()


def _run_c_flow(installer: "CInstaller") -> None:
    """Dispatch the release-specific middle phases of the C installer."""
    flow = installer.settings.flow
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
    settings = session.config.install
    assert isinstance(settings, UnattendedInstallConfig)
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

    def __init__(self, session: InstallSession, config: CInstallConfig | None = None) -> None:
        """Initialize the C-installer driver with typed release configuration."""
        self.s = session
        config = config or session.config.install
        assert isinstance(config, CInstallConfig)
        self.disk = config.disk
        self.locale = config.locale
        self.prompts = config.prompts
        self.network_config = config.network
        self.settings = config.redhat
        self.dialog = NewtDialog(session)

    def dialog_step(
        self,
        title: str,
        button: str = "Ok",
        *,
        advance: bool = True,
    ) -> None:
        """Wait for a dialog and perform its source-defined button action."""
        self.dialog.wait_for_title(title)
        if advance:
            self.dialog.advance(button)
        else:
            self.dialog.press_button(button)

    def _flow_42(self) -> None:
        """Run the Red Hat 4.2 component-selection variant."""
        self.partition_4x()
        self._components(COMPONENTS_42)
        self.finish_components()
        self.x11_4x()

    def _flow_5x(self) -> None:
        """Run the Red Hat 5.0 or 5.1 partition and X11 phases."""
        flow = self.settings.flow
        self.dialog_step("Disk Setup", "fdisk", advance=False)
        self.dialog.wait_for_title("Partition Disks")
        self.partition_helper()
        self.dialog.advance("Done")
        self._partition_5x(flow)
        self.components_default()
        self.finish_components()
        self._configure_mouse_5x(flow)
        self.x11_5x()

    def _configure_mouse_5x(self, flow: str) -> None:
        """Configure the release-specific mouseconfig screens."""
        self.dialog_step("Probing Result")
        if flow == "50":
            self.dialog_step("Emulate Three Buttons", "Yes")
            return

        # mouseconfig 2.6 mouseTypeWindow() combines its mouse list,
        # emulation checkbox, and buttons in one "Configure Mouse" form.
        self.dialog.wait_for_title("Configure Mouse")
        self.dialog.select_menu_item("PS/2 Mouse")
        self.dialog.set_checkbox("Emulate 3 Buttons?", True)
        self.dialog.advance("Ok")

    def _partition_5x(self, flow: str) -> None:
        """Complete release-specific root and format screens for Red Hat 5.x."""
        if flow == "50":
            self.dialog.wait_for_title("Select Root Partition")
            self.dialog.select_partition(self.disk.root_partition)
            self.dialog.advance("Ok")
            self.dialog_step("Partition Disk")
            self.dialog_step("Active Swap Space")
            self.dialog.wait_for_title("Format Partitions")
            self.dialog.set_partition_checklist_item(self.disk.root_partition, True)
            self.dialog.advance("Ok")
            return
        self.dialog.wait_for_title("Current Disk Partitions")
        self.dialog.select_partition(self.disk.root_partition)
        self.dialog.press_button("Edit")
        self.dialog.wait_for_title(f"Edit Partition: {self.disk.root_partition}")
        self.dialog.enter_text("/", field="mount point")
        self.dialog.advance("Ok")
        self.dialog_step("Active Swap Space")
        self.dialog.wait_for_title("Partitions To Format")
        self.dialog.set_partition_checklist_item(self.disk.root_partition, True)
        self.dialog.advance("Ok")

    def start(self) -> None:
        """Complete the initial language, media, and install-mode screens."""
        o = self.settings
        self.s.vga_wait(self.prompts.boot_prompt, match=Match.LINE)
        self.s.kb_type(f"{self.prompts.boot_command}\n")
        if self.prompts.boot_sleep:
            time.sleep(self.prompts.boot_sleep)
        if o.color_prompt:
            self.dialog.wait_for_title("Color Choices")
            self.dialog.advance("Yes")
        self.dialog_step("Red Hat Linux")
        if o.language_prompt:
            self.dialog_step("Choose a Language")
        if o.keyboard_early:
            self.dialog.wait_for_title("Keyboard Type")
            self.dialog.select_menu_item(self.locale.keymap)
            self.dialog.advance("Ok")
        if o.pcmcia_prompt:
            self.dialog_step("PCMCIA Support", "No")
        self.dialog_step("Installation Method")
        self.dialog_step("Note")
        if o.cdrom_type_prompt:
            self.dialog_step("CDROM type")
        self.dialog_step("Installation Path", "Install")
        self.dialog_step("SCSI Configuration", "No")

    def partition_helper(self) -> None:
        """Run the early graphical partition helper workflow."""
        self.s.kb_press("alt-f2")
        self.s.serial_shell_start(screen_prompt="bash#")
        Fdisk(self.s).partition_swap_root(self.disk.target_disk, self.disk.swap_mb)
        self.s.serial.wait("#", line=True)
        self.s.serial_shell_exit(screen_prompt="bash#")
        self.s.kb_press("alt-f1")

    def partition_4x(self) -> None:
        """Partition a Red Hat 4.x target with the scripted fdisk workflow."""
        self.dialog.wait_for_title("Partition Disks")
        self.partition_helper()
        self.dialog_step("Partition Disks", "Done")
        self.dialog_step("Active Swap Space")
        self.dialog.wait_for_title("Select Root Partition")
        self.dialog.select_partition(self.disk.root_partition)
        self.dialog.advance("Ok")
        self.dialog.wait_for_title("Partition Disk")
        self.dialog.select_partition(self.disk.fat_partition)
        self.dialog.press_button("Edit")
        self.dialog.wait_for_title("Edit Mount Point")
        self.dialog.enter_text(self.disk.fat_mount, field="mount point")
        self.dialog.advance("Ok")
        self.dialog.wait_for_title("Format Partitions")
        self.dialog.set_partition_checklist_item(self.disk.root_partition, True)
        self.dialog.advance("Ok")

    def components_40(self) -> None:
        """Select Red Hat 4.0 component groups."""
        self._components(COMPONENTS_40)

    def _components(self, choices: dict[str, bool]) -> None:
        """Apply source-defined component selections and accept the form."""
        self.dialog.wait_for_title("Components to Install")
        self.dialog.set_checklist_items(choices)
        self.dialog.advance("Ok")

    def components_default(self) -> None:
        """Accept the default component selection."""
        self.dialog_step("Components to Install")

    def finish_components(self) -> None:
        """Finish component selection and begin package installation."""
        self.dialog_step("Install log")
        if self.settings.keyboard_after_packages:
            self._configure_keyboard()

    def x11_4x(self) -> None:
        """Configure X11 screens used by Red Hat 4.x."""
        self.dialog.wait_for_title("Configure Mouse")
        self.dialog.select_menu_item("PS/2 Mouse")
        self.dialog.set_checkbox("Emulate 3 Buttons?", True)
        self.dialog.advance("Ok")
        self.dialog.wait_for_title("Choose A Card")
        # Xconfigurator 2.0.1 renders sprintf("%-49s%s", name, chipset).
        self.dialog.select_menu_item(self.settings.x_card_label, label_width=49)
        self.dialog.advance("Ok")
        self.dialog.wait_for_title("Monitor Setup")
        self.dialog.move_focus("down")
        self.dialog.advance("Ok")
        self.dialog.wait_for_title("Video Memory")
        self.dialog.select_menu_item(self.settings.x_video_memory_label)
        self.dialog.advance("Ok")
        self.dialog_step("Clockchip Configuration")
        self.dialog_step("Select Video Modes")

    def x11_5x(self) -> None:
        """Configure X11 screens used by Red Hat 5.x."""
        # "X Server : SVGA" is message text; Xconfigurator 3.x titles the
        # containing dialog "PCI Probe".
        self.dialog_step("PCI Probe")
        self.dialog.wait_for_title("Monitor Setup")
        self.dialog.move_focus("down")
        self.dialog.advance("Ok")
        self.dialog_step("Screen Configuration", "Don't Probe")
        self.dialog.wait_for_title("Video Memory")
        self.dialog.select_menu_item(self.settings.x_video_memory_label)
        self.dialog.advance("Ok")
        self.dialog_step("Clockchip Configuration")
        self.dialog_step("Select Video Modes")

    def network(self) -> None:
        """Configure Red Hat networking and resolver settings."""
        o = self.settings
        n = self.network_config
        self.dialog_step("Network Configuration", "Yes")
        if o.flow == "51":
            # devices.c auto-loads a uniquely matched PCI driver, reports it
            # in a "Probe" message, and returns before the manual module menu.
            self.dialog_step("Probe")
            self.dialog.wait_for_title("Boot Protocol")
            self.dialog.select_menu_item("Static IP address")
            self.dialog.advance("Ok")
        self.dialog.wait_for_title("Configure TCP/IP")
        self.dialog.enter_text(n.ip, field="IP address")
        for value in (n.netmask, n.network, n.broadcast):
            self.dialog.replace_text(value, field="TCP/IP address")
        self.dialog.advance("Ok")
        self.dialog.wait_for_title("Configure Network")
        self.dialog.enter_text(n.domain, field="domain name")
        self.dialog.enter_text(n.hostname, field="hostname")
        for value in (n.gateway, n.nameserver):
            self.dialog.replace_text(value, field="network address")
        self.dialog.advance("Ok")

    def finish(self) -> None:
        """Complete installation and launch post-installation setup."""
        o = self.settings
        hostname = self.network_config.hostname
        self._finish_configuration()
        self._install_lilo()
        # Red Hat 4.0 install2.c finishes with winMessage(..., "Done", ...).
        self.dialog.wait_for_title("Done")
        self.s.set_boot("c")
        self.dialog.advance("Ok")
        self.s.run_postinst(
            o.password,
            login=f"{hostname} login:",
            shell=f"[root@{hostname} /root]#",
        )

    def _finish_configuration(self) -> None:
        """Answer final service, printer, account, and boot-disk screens."""
        o = self.settings
        self.dialog.wait_for_title(o.timezone_prompt)
        if o.timezone_clock_control == "checkbox":
            self.dialog.set_checkbox(
                "Hardware clock set to GMT",
                self.locale.hardware_clock == "utc",
            )
        else:
            clock_label = (
                "Universal time (GMT)"
                if self.locale.hardware_clock == "utc"
                else "Local time"
            )
            self.dialog.set_radio(clock_label)
        self.dialog.select_menu_item(self.locale.timezone)
        self.dialog.advance(o.timezone_button)
        if o.keyboard_late:
            self._configure_keyboard()
        if o.flow in {"50", "51"}:
            self.dialog_step("Services")
        if o.flow == "42":
            self.dialog_step("Add Printers", "No", advance=False)
        elif o.flow in {"50", "51"}:
            self.dialog_step("Configure Printer", "No", advance=False)
        self.dialog.wait_for_title("Root Password")
        self.dialog.enter_text(o.password, field="root password", sensitive=True)
        self.dialog.enter_text(o.password, field="confirmation", sensitive=True)
        self.dialog.advance("Ok")
        if o.bootdisk_prompt:
            self.dialog_step("Bootdisk", "No", advance=False)

    def _configure_keyboard(self) -> None:
        """Select the configured keymap in the external kbdconfig utility."""
        self.dialog.wait_for_title("Configure Keyboard")
        self.dialog.select_menu_item(self.locale.keymap)
        self.dialog.advance("Okay")

    def _install_lilo(self) -> None:
        """Install LILO while excluding the staged FAT disk from its boot menu."""
        for _ in range(self.settings.lilo_setup_dialogs):
            self.dialog_step("Lilo Installation")
        if not self.settings.lilo_boot_labels:
            return
        self.dialog.wait_for_title("Bootable Partitions")
        self.dialog.select_partition(self.disk.fat_partition)
        self.dialog.press_button("Edit")
        self.dialog.wait_for_title("Edit Boot Label")
        # lilo.c assigns the first DOS partition "dos"; the historical driver
        # selected that row and erased its three-character label.
        self.dialog.replace_text("", field="boot label")
        self.dialog.wait_for_title("Bootable Partitions")
        self.dialog.advance("Ok")
