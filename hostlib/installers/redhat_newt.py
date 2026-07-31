"""Automate Red Hat releases that use the full-screen Newt installer driver."""

from __future__ import annotations

from dataclasses import dataclass
import time
from typing import Literal, assert_never

from ..fdisk import Fdisk
from ..session import InstallSession
from ..newt_dialog import NewtDialog
from ..schemas import RedHatNewtInstallConfig, UnattendedInstallConfig

PartitionWorkflow = Literal[
    "partition-disks",
    "select-root-partition",
    "current-disk-partitions",
]
MouseWorkflow = Literal[
    "configure-mouse",
    "probe-and-emulation",
    "probe-and-configure-mouse",
]
X11Workflow = Literal["choose-card", "pci-probe"]
NetworkWorkflow = Literal["direct", "probe-static"]
TcpIpForm = Literal["gateway-and-nameserver", "network-and-broadcast"]
KeyboardStage = Literal["early", "after-packages", "late"]


@dataclass(frozen=True)
class NewtVariant:
    """Describe one release's fixed Newt screen sequence and labels."""

    partitioning: PartitionWorkflow = "partition-disks"
    mouse_setup: MouseWorkflow = "configure-mouse"
    x11_setup: X11Workflow = "choose-card"
    network_setup: NetworkWorkflow = "direct"
    tcp_ip_form: TcpIpForm = "gateway-and-nameserver"
    color_prompt: bool = True
    language_prompt: bool = False
    keyboard_stage: KeyboardStage | None = None
    pcmcia_prompt: bool = True
    cdrom_type_prompt: bool = True
    services_prompt: bool = False
    printer_prompt: str | None = None
    x_video_memory_label: str = "2048"
    timezone_checkbox: bool = False
    extra_lilo_dialog: bool = False
    boot_label_field: str = "Boot label :"
    bootdisk_prompt: bool = False
    password_field: str = "Password        :"


VARIANT_40 = NewtVariant(
    tcp_ip_form="network-and-broadcast",
    keyboard_stage="late",
)
VARIANT_41 = NewtVariant(
    keyboard_stage="after-packages",
    timezone_checkbox=True,
    extra_lilo_dialog=True,
)
VARIANT_42 = NewtVariant(
    keyboard_stage="early",
    cdrom_type_prompt=False,
    printer_prompt="Add Printers",
    timezone_checkbox=True,
    extra_lilo_dialog=True,
)
VARIANT_50 = NewtVariant(
    partitioning="select-root-partition",
    mouse_setup="probe-and-emulation",
    x11_setup="pci-probe",
    keyboard_stage="early",
    pcmcia_prompt=False,
    cdrom_type_prompt=False,
    services_prompt=True,
    printer_prompt="Configure Printer",
    x_video_memory_label="2 meg",
    timezone_checkbox=True,
    extra_lilo_dialog=True,
)
VARIANT_51 = NewtVariant(
    partitioning="current-disk-partitions",
    mouse_setup="probe-and-configure-mouse",
    x11_setup="pci-probe",
    network_setup="probe-static",
    color_prompt=False,
    language_prompt=True,
    keyboard_stage="early",
    pcmcia_prompt=False,
    cdrom_type_prompt=False,
    services_prompt=True,
    printer_prompt="Configure Printer",
    x_video_memory_label="2 meg",
    timezone_checkbox=True,
    extra_lilo_dialog=True,
    boot_label_field="Boot label:",
    bootdisk_prompt=True,
    password_field="Password:",
)

VARIANTS = {
    "4.0": VARIANT_40,
    "4.1": VARIANT_41,
    "4.2": VARIANT_42,
    "5.0": VARIANT_50,
    "5.1": VARIANT_51,
}


def run_redhat_newt(session: InstallSession) -> None:
    """Run the configured Red Hat Newt installer variant."""
    config = session.config.install
    assert isinstance(config, RedHatNewtInstallConfig)
    variant = VARIANTS[config.variant]
    installer = NewtInstaller(session, variant)
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


def run_redhat_unattended(session: InstallSession) -> None:
    """Wait for an unattended Red Hat install and complete post-install setup."""
    config = session.config.install
    assert isinstance(config, UnattendedInstallConfig)
    session.boot_command(config.boot.prompt, config.boot.command)
    session.vga_wait(config.completion.prompt)
    if config.completion.reboot:
        session.set_boot(config.completion.boot_device)
        session.kb_type("\n")
    if config.completion.postinst:
        session.run_postinst(
            config.accounts.root_password,
            login=config.prompts.login_prompt,
            shell=config.prompts.shell_prompt,
        )


class NewtInstaller:
    """Drive reusable phases of Red Hat's Newt installer screens.

    The top-level entry point composes common phases whose screen workflows are
    selected independently. Keyboard movement is explicit because these
    installers do not emit the guestlib dialog protocol.
    """

    def __init__(
        self,
        session: InstallSession,
        variant: NewtVariant,
    ) -> None:
        """Initialize the Newt driver with typed release configuration."""
        self.s = session
        config = session.config.install
        assert isinstance(config, RedHatNewtInstallConfig)
        self.disk = config.disk
        self.locale = config.locale
        self.prompts = config.prompts
        self.network_config = config.network
        self.components = config.packages.components
        self.root_password = config.accounts.root_password
        self.variant = variant
        self.dialog = NewtDialog(session)

    def partition_storage(self) -> None:
        """Partition storage with the configured installer screen workflow."""
        workflow = self.variant.partitioning
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
        elif workflow == "current-disk-partitions":
            self._edit_current_disk_partitions()
        else:
            assert_never(workflow)

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
        workflow = self.variant.mouse_setup
        if workflow == "configure-mouse":
            pass
        elif workflow in {"probe-and-emulation", "probe-and-configure-mouse"}:
            self.dialog.wait_for_title("Probing Result")
            self.dialog.advance()
        else:
            assert_never(workflow)
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
        variant = self.variant
        self.s.boot_command(self.prompts.boot_prompt, self.prompts.boot_command)
        if self.prompts.boot_sleep:
            time.sleep(self.prompts.boot_sleep)
        if variant.color_prompt:
            self.dialog.wait_for_title("Color Choices")
            self.dialog.advance("Yes")
        self.dialog.wait_for_title("Red Hat Linux")
        self.dialog.advance()
        if variant.language_prompt:
            self.dialog.wait_for_title("Choose a Language")
            self.dialog.select_menu_item("English")
            self.dialog.advance()
        if variant.keyboard_stage == "early":
            self.dialog.wait_for_title("Keyboard Type")
            self.dialog.select_menu_item(self.locale.keymap)
            self.dialog.advance()
        if variant.pcmcia_prompt:
            self.dialog.wait_for_title("PCMCIA Support")
            self.dialog.advance("No")
        self.dialog.wait_for_title("Installation Method")
        self.dialog.select_menu_item("Local CDROM")
        self.dialog.advance()
        self.dialog.wait_for_title("Note")
        self.dialog.advance()
        if variant.cdrom_type_prompt:
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
        self.dialog.set_checklist_items(self.components)
        self.dialog.advance()

    def begin_package_installation(self) -> None:
        """Accept the install log notice and begin package installation."""
        self.dialog.wait_for_title("Install log")
        self.dialog.advance()
        if self.variant.keyboard_stage == "after-packages":
            self._configure_keyboard()

    def configure_x11(self) -> None:
        """Configure X11 with the selected screen workflow."""
        workflow = self.variant.x11_setup
        if workflow == "choose-card":
            self.dialog.wait_for_title("Choose A Card")
            self.dialog.select_menu_item("Cirrus Logic GD543x", label_width=49)
            self.dialog.advance()
            pci_probe = False
        elif workflow == "pci-probe":
            self.dialog.wait_for_title("PCI Probe")
            self.dialog.advance()
            pci_probe = True
        else:
            assert_never(workflow)
        self.dialog.wait_for_title("Monitor Setup")
        self.dialog.select_menu_item("Generic Monitor")
        self.dialog.advance()
        if pci_probe:
            self.dialog.wait_for_title("Screen Configuration")
            self.dialog.advance("Don't Probe")
        self.dialog.wait_for_title("Video Memory")
        self.dialog.select_menu_item(self.variant.x_video_memory_label)
        self.dialog.advance()
        self.dialog.wait_for_title("Clockchip Configuration")
        self.dialog.select_menu_item("No Clockchip Setting (recommended)")
        self.dialog.advance()
        self.dialog.wait_for_title("Select Video Modes")
        self.dialog.advance()

    def configure_network(self) -> None:
        """Configure Red Hat networking and resolver settings."""
        variant = self.variant
        network = self.network_config
        self.dialog.wait_for_title("Network Configuration")
        self.dialog.advance("Yes")
        if variant.network_setup == "probe-static":
            self.dialog.wait_for_title("Probe")
            self.dialog.advance()
            self.dialog.wait_for_title("Boot Protocol")
            self.dialog.select_menu_item("Static IP address")
            self.dialog.advance()
        elif variant.network_setup != "direct":
            assert_never(variant.network_setup)
        self.dialog.wait_for_title("Configure TCP/IP")
        if variant.tcp_ip_form == "network-and-broadcast":
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
        elif variant.tcp_ip_form == "gateway-and-nameserver":
            tcp_ip_tail = {
                "Default gateway (IP):": network.gateway,
                "Primary nameserver:": network.nameserver,
            }
            network_tail = {
                "Secondary nameserver (IP):": "",
                "Tertiary nameserver (IP):": "",
            }
        else:
            assert_never(variant.tcp_ip_form)
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
            self.root_password,
            login=f"{hostname} login:",
            shell=f"[root@{hostname} /root]#",
        )

    def configure_installed_system(self) -> None:
        """Configure timezone, services, printing, accounts, and boot media."""
        variant = self.variant
        self.dialog.wait_for_title("Configure Timezones")
        if variant.timezone_checkbox:
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
        if variant.keyboard_stage == "late":
            self._configure_keyboard()
        if variant.services_prompt:
            self.dialog.wait_for_title("Services")
            self.dialog.advance()
        if variant.printer_prompt is not None:
            self.dialog.wait_for_title(variant.printer_prompt)
            self.dialog.press_button("No")
        self.dialog.wait_for_title("Root Password")
        self.dialog.set_fields(
            {
                variant.password_field: self.root_password,
                "Password (again):": self.root_password,
            },
            sensitive=True,
        )
        self.dialog.advance()
        if variant.bootdisk_prompt:
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
        if self.variant.extra_lilo_dialog:
            self.dialog.wait_for_title("Lilo Installation")
            self.dialog.advance()
        self.dialog.wait_for_title("Bootable Partitions")
        self.dialog.select_partition(self.disk.fat_partition)
        self.dialog.press_button("Edit")
        self.dialog.wait_for_title("Edit Boot Label")
        self.dialog.set_fields({self.variant.boot_label_field: ""})
        self.dialog.press_button("Ok")
        self.dialog.wait_for_title("Bootable Partitions")
        self.dialog.advance()
