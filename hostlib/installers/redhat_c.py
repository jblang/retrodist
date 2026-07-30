"""Automate Red Hat releases that use the full-screen C installer driver.

The supported releases share broad phases while selecting explicit partition,
mouse, X11, and network screen workflows from configuration. Kickstart-based
releases use the smaller unattended entry point in this module.
"""

from __future__ import annotations

import time

from ..fdisk import Fdisk
from ..session import InstallSession
from ..newt_dialog import NewtDialog
from ..schemas import CInstallConfig, UnattendedInstallConfig


def run_c_installer(session: InstallSession) -> None:
    """Run a Red Hat C-installer installation with validated configuration."""
    installer = CInstaller(session)
    installer.boot_and_select_installation_options()
    installer.partition_storage()
    installer.select_components()
    installer.begin_package_installation()
    installer.configure_mouse()
    installer.configure_x11()
    installer.configure_network()
    installer.configure_installed_system()
    installer.configure_bootloader()
    installer.complete_installation()


def run_unattended(session: InstallSession) -> None:
    """Wait for an unattended Red Hat install and complete post-install setup."""
    settings = session.config.install
    assert isinstance(settings, UnattendedInstallConfig)
    session.boot_command(settings.boot.prompt, settings.boot.command)
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

    The top-level entry point composes common phases whose screen workflows are
    selected independently. Keyboard movement is explicit because these
    installers do not emit the guestlib dialog protocol.
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

    def partition_storage(self) -> None:
        """Partition storage with the configured installer screen workflow."""
        workflow = self.settings.partitioning
        if workflow == "partition-disks":
            self._partition_disks()
            return

        self.dialog.wait_for_title("Disk Setup")
        self.dialog.press_button("fdisk")
        self.dialog.wait_for_title("Partition Disks")
        self._create_partitions_with_fdisk()
        self.dialog.advance("Done")
        if workflow == "select-root-partition":
            self._select_root_partition()
        else:
            self._edit_current_disk_partitions()

    def _select_root_partition(self) -> None:
        """Use the Select Root Partition and Format Partitions screens."""
        self.dialog.wait_for_title("Select Root Partition")
        self.dialog.select_partition(self.disk.root_partition)
        self.dialog.advance()
        self.dialog.wait_for_title("Partition Disk")
        self.dialog.advance()
        self.dialog.wait_for_title("Active Swap Space")
        self.dialog.advance()
        self.dialog.wait_for_title("Format Partitions")
        self.dialog.check_partition(self.disk.root_partition)
        self.dialog.advance()

    def _edit_current_disk_partitions(self) -> None:
        """Edit the root row in the Current Disk Partitions screen."""
        self.dialog.wait_for_title("Current Disk Partitions")
        self.dialog.select_partition(self.disk.root_partition)
        self.dialog.press_button("Edit")
        self.dialog.wait_for_title(f"Edit Partition: {self.disk.root_partition}")
        self.dialog.set_fields({"Mount Point:": "/"})
        self.dialog.press_button("Ok")
        self.dialog.wait_for_title("Current Disk Partitions")
        self.dialog.advance()
        self.dialog.wait_for_title("Active Swap Space")
        self.dialog.advance()
        self.dialog.wait_for_title("Partitions To Format")
        self.dialog.check_partition(self.disk.root_partition)
        self.dialog.advance()

    def configure_mouse(self) -> None:
        """Configure the mouse with the selected screen workflow."""
        workflow = self.settings.mouse_setup
        if workflow != "configure-mouse":
            self.dialog.wait_for_title("Probing Result")
            self.dialog.advance()
        if workflow == "probe-and-emulation":
            self.dialog.wait_for_title("Emulate Three Buttons")
            self.dialog.advance("Yes")
            return

        self.dialog.wait_for_title("Configure Mouse")
        self.dialog.select_menu_item("PS/2 Mouse")
        self.dialog.set_checkbox("Emulate 3 Buttons?")
        self.dialog.advance()

    def boot_and_select_installation_options(self) -> None:
        """Boot the installer and select its language, media, and install mode."""
        settings = self.settings
        self.s.boot_command(self.prompts.boot_prompt, self.prompts.boot_command)
        if self.prompts.boot_sleep:
            time.sleep(self.prompts.boot_sleep)
        if settings.color_prompt:
            self.dialog.wait_for_title("Color Choices")
            self.dialog.advance("Yes")
        self.dialog.wait_for_title("Red Hat Linux")
        self.dialog.advance()
        if settings.language_prompt:
            self.dialog.wait_for_title("Choose a Language")
            self.dialog.select_menu_item("English")
            self.dialog.advance()
        if settings.keyboard_early:
            self.dialog.wait_for_title("Keyboard Type")
            self.dialog.select_menu_item(self.locale.keymap)
            self.dialog.advance()
        if settings.pcmcia_prompt:
            self.dialog.wait_for_title("PCMCIA Support")
            self.dialog.advance("No")
        self.dialog.wait_for_title("Installation Method")
        self.dialog.select_menu_item("Local CDROM")
        self.dialog.advance()
        self.dialog.wait_for_title("Note")
        self.dialog.advance()
        if settings.cdrom_type_prompt:
            self.dialog.wait_for_title("CDROM type")
            self.dialog.select_menu_item("IDE (ATAPI)")
            self.dialog.advance()
        self.dialog.wait_for_title("Installation Path")
        self.dialog.advance("Install")
        self.dialog.wait_for_title("SCSI Configuration")
        self.dialog.advance("No")

    def _create_partitions_with_fdisk(self) -> None:
        """Create the swap and root partitions from the installer's shell."""
        self.s.kb_press("alt-f2")
        self.s.serial_shell_start(screen_prompt="bash#")
        Fdisk(self.s).partition_swap_root(self.disk.target_disk, self.disk.swap_mb)
        self.s.serial_shell_exit(screen_prompt="bash#")
        self.s.kb_press("alt-f1")

    def _partition_disks(self) -> None:
        """Use the Partition Disks workflow with the scripted fdisk helper."""
        self.dialog.wait_for_title("Partition Disks")
        self._create_partitions_with_fdisk()
        self.dialog.wait_for_title("Partition Disks")
        self.dialog.advance("Done")
        self.dialog.wait_for_title("Active Swap Space")
        self.dialog.advance()
        self.dialog.wait_for_title("Select Root Partition")
        self.dialog.select_partition(self.disk.root_partition)
        self.dialog.advance()
        self.dialog.wait_for_title("Partition Disk")
        self.dialog.select_partition(self.disk.fat_partition)
        self.dialog.press_button("Edit")
        self.dialog.wait_for_title("Edit Mount Point")
        self.dialog.set_fields({"Mount point :": self.disk.fat_mount})
        self.dialog.press_button("Ok")
        self.dialog.wait_for_title("Partition Disk")
        self.dialog.advance()
        self.dialog.wait_for_title("Format Partitions")
        self.dialog.check_partition(self.disk.root_partition)
        self.dialog.advance()

    def select_components(self) -> None:
        """Apply the configured component set and accept the form."""
        self.dialog.wait_for_title("Components to Install")
        self.dialog.set_checklist_items(self.settings.components)
        self.dialog.advance()

    def begin_package_installation(self) -> None:
        """Accept the install log notice and begin package installation."""
        self.dialog.wait_for_title("Install log")
        self.dialog.advance()
        if self.settings.keyboard_after_packages:
            self._configure_keyboard()

    def configure_x11(self) -> None:
        """Configure X11 with the selected screen workflow."""
        pci_probe = self.settings.x11_setup == "pci-probe"
        if not pci_probe:
            self.dialog.wait_for_title("Choose A Card")
            self.dialog.select_menu_item(self.settings.x_card_label, label_width=49)
            self.dialog.advance()
        else:
            self.dialog.wait_for_title("PCI Probe")
            self.dialog.advance()
        self.dialog.wait_for_title("Monitor Setup")
        self.dialog.select_menu_item("Generic Monitor")
        self.dialog.advance()
        if pci_probe:
            self.dialog.wait_for_title("Screen Configuration")
            self.dialog.advance("Don't Probe")
        self.dialog.wait_for_title("Video Memory")
        self.dialog.select_menu_item(self.settings.x_video_memory_label)
        self.dialog.advance()
        self.dialog.wait_for_title("Clockchip Configuration")
        self.dialog.select_menu_item("No Clockchip Setting (recommended)")
        self.dialog.advance()
        self.dialog.wait_for_title("Select Video Modes")
        self.dialog.advance()

    def configure_network(self) -> None:
        """Configure Red Hat networking and resolver settings."""
        settings = self.settings
        network = self.network_config
        self.dialog.wait_for_title("Network Configuration")
        self.dialog.advance("Yes")
        if settings.network_setup == "probe-static":
            self.dialog.wait_for_title("Probe")
            self.dialog.advance()
            self.dialog.wait_for_title("Boot Protocol")
            self.dialog.select_menu_item("Static IP address")
            self.dialog.advance()
        self.dialog.wait_for_title("Configure TCP/IP")
        if settings.tcp_ip_form == "network-and-broadcast":
            tcp_ip_tail = {
                "Network address:": network.network,
                "Broadcast address:": network.broadcast,
            }
            network_tail = {
                "Default gateway (IP):": network.gateway,
                "Primary nameserver (IP):": network.nameserver,
                "Secondary nameserver (IP):": "",
                "Tertiary nameserver (IP):": "",
            }
        else:
            tcp_ip_tail = {
                "Default gateway (IP):": network.gateway,
                "Primary nameserver:": network.nameserver,
            }
            network_tail = {
                "Secondary nameserver (IP):": "",
                "Tertiary nameserver (IP):": "",
            }
        self.dialog.set_fields(
            {
                "IP address:": network.ip,
                "Netmask:": network.netmask,
                **tcp_ip_tail,
            }
        )
        self.dialog.advance()

        self.dialog.wait_for_title("Configure Network")
        self.dialog.set_fields(
            {
                "Domain name:": network.domain,
                "Host name:": network.hostname,
                **network_tail,
            }
        )
        self.dialog.advance()

    def complete_installation(self) -> None:
        """Dismiss the completion screen and launch post-installation setup."""
        hostname = self.network_config.hostname
        self.dialog.wait_for_title("Done")
        self.s.set_boot("c")
        self.dialog.advance()
        self.s.run_postinst(
            self.settings.password,
            login=f"{hostname} login:",
            shell=f"[root@{hostname} /root]#",
        )

    def configure_installed_system(self) -> None:
        """Configure timezone, services, printing, accounts, and boot media."""
        settings = self.settings
        self.dialog.wait_for_title(settings.timezone_prompt)
        if settings.timezone_clock_control == "checkbox":
            self.dialog.set_checkbox(
                "Hardware clock set to GMT",
                self.locale.hardware_clock == "utc",
            )
        else:
            clock_label = (
                "Universal time (GMT)" if self.locale.hardware_clock == "utc" else "Local time"
            )
            self.dialog.set_radio(clock_label)
        self.dialog.select_menu_item(self.locale.timezone)
        self.dialog.advance()
        if settings.keyboard_late:
            self._configure_keyboard()
        if settings.services_prompt:
            self.dialog.wait_for_title("Services")
            self.dialog.advance()
        if settings.printer_prompt is not None:
            self.dialog.wait_for_title(settings.printer_prompt)
            self.dialog.press_button("No")
        self.dialog.wait_for_title("Root Password")
        self.dialog.set_fields(
            {
                settings.password_field: settings.password,
                "Password (again):": settings.password,
            },
            sensitive=True,
        )
        self.dialog.advance()
        if settings.bootdisk_prompt:
            self.dialog.wait_for_title("Bootdisk")
            self.dialog.press_button("No")

    def _configure_keyboard(self) -> None:
        """Select the configured keymap in the external kbdconfig utility."""
        self.dialog.wait_for_title("Configure Keyboard")
        self.dialog.select_menu_item(self.locale.keymap)
        self.dialog.advance()

    def configure_bootloader(self) -> None:
        """Configure LILO while excluding the staged FAT disk from its boot menu."""
        self.dialog.wait_for_title("Lilo Installation")
        self.dialog.select_menu_item(f"{self.disk.target_disk} Master Boot Record")
        self.dialog.advance()
        for _ in range(self.settings.lilo_setup_dialogs - 1):
            self.dialog.wait_for_title("Lilo Installation")
            self.dialog.advance()
        if not self.settings.lilo_boot_labels:
            return
        self.dialog.wait_for_title("Bootable Partitions")
        self.dialog.select_partition(self.disk.fat_partition)
        self.dialog.press_button("Edit")
        self.dialog.wait_for_title("Edit Boot Label")
        self.dialog.set_fields({self.settings.boot_label_field: ""})
        self.dialog.press_button("Ok")
        self.dialog.wait_for_title("Bootable Partitions")
        self.dialog.advance()
