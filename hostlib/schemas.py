"""Typed installer configuration schemas."""

from __future__ import annotations

from typing import Annotated, Literal

from pydantic import Field, RootModel

from .media_schemas import NetworkConfig
from .schema_base import ConfigModel


class InstallDiskConfig(ConfigModel):
    """Configure paths and partition defaults shared by installer drivers."""

    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    swap_partition: str = "/dev/hda1"
    root_partition: str = "/dev/hda2"
    fat_partition: str = "/dev/hdb1"
    fat_mount: str = "/retro"
    fat_filesystem: str = "msdos"


class InstallLocaleConfig(ConfigModel):
    """Configure installer locale choices shared by family drivers."""

    hardware_clock: Literal["utc", "local"] = "utc"
    keymap: str = "us"
    timezone: str = "UTC"


class InstallPromptsConfig(ConfigModel):
    """Configure prompts shared by installer lifecycle variants."""

    boot_prompt: str = "boot:"
    boot_command: str = ""
    boot_sleep: float = 0
    postinst_prompt: str | None = None


class DebianDialogNetworkConfig(NetworkConfig):
    """Add Debian installer module controls to static networking."""

    net_module: str | None = None
    net_module_args: str = ""


class DebianAccountsConfig(ConfigModel):
    """Configure Debian Dinstall accounts."""

    root_password: str = "password1"
    user: str = "debian"
    user_password: str = "password1"


class SlackwareDialogPackagesConfig(ConfigModel):
    """Configure Slackware dialog-installer package media and selection."""

    source: str = "/dev/hdc"
    tagfile_path: str | Literal[False] | None = "/retro/tagfiles"
    package_sets: str = '"A" "AP" "N" "X" "XAP"'


class SlackwareBootloaderConfig(ConfigModel):
    """Configure Slackware boot-loader choices."""

    framebuffer: str = "standard"
    label: str = "linux"


class SlackwareModemConfig(ConfigModel):
    """Configure Slackware modem choices."""

    speed: str = "38400"


class SlackwareMailConfig(ConfigModel):
    """Configure Slackware mail choices."""

    mode: str = "SMTP"


class RedHatNewtPackagesConfig(ConfigModel):
    """Select the Red Hat package components to install."""

    components: list[str]


class RedHatDialogPackagesConfig(ConfigModel):
    """Select the early Red Hat package series to install."""

    package_series: list[str]


class RedHatDialogAccountsConfig(ConfigModel):
    """Configure early Red Hat installer accounts."""

    root_password: str = ""
    user: str | None = Field(default=None, min_length=1, max_length=8)
    user_home: bool = True


class SlackwareTtyPackagesConfig(ConfigModel):
    """Select package sets used by Slackware's early tty setup program."""

    package_sets: str = "A AP D E F IV N TCL OI OOP X XAP XD XV Y"


class DebianDialogBootConfig(ConfigModel):
    """Configure Debian installer boot and root-disk prompts."""

    prompt: str = "boot:"
    command: str = ""
    root_prompt: str | None = None
    root_image: str = "root.img"


class UnattendedBootConfig(ConfigModel):
    """Configure unattended Red Hat boot input."""

    prompt: str = "boot:"
    command: str


class UnattendedCompletionConfig(ConfigModel):
    """Configure unattended Red Hat completion handling."""

    prompt: str
    reboot: bool = True
    postinst: bool = False
    boot_device: str = "c"


class RedHatAccountsConfig(ConfigModel):
    """Configure optional Red Hat root credentials."""

    root_password: str | None = None


class RedHatNewtAccountsConfig(ConfigModel):
    """Configure the root credential required by the Newt installer."""

    root_password: str = "password"


class UnattendedPromptsConfig(ConfigModel):
    """Configure login prompts used after an unattended installation."""

    login_prompt: str = "login:"
    shell_prompt: str = "#"


class UnattendedInstallConfig(ConfigModel):
    """Configure an unattended Red Hat installation lifecycle."""

    driver: Literal["redhat-unattended"]
    boot: UnattendedBootConfig
    completion: UnattendedCompletionConfig
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    accounts: RedHatAccountsConfig = Field(default_factory=RedHatAccountsConfig)
    prompts: UnattendedPromptsConfig = Field(default_factory=UnattendedPromptsConfig)


class DebianDialogInstallConfig(ConfigModel):
    """Validate the complete Debian Dinstall configuration."""

    driver: Literal["debian-dialog"]
    variant: Literal["1.1", "1.2", "1.3", "1.3-vfat"]
    boot: DebianDialogBootConfig = Field(default_factory=DebianDialogBootConfig)
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(
        default_factory=lambda: InstallLocaleConfig(timezone="Etc/UTC")
    )
    network: DebianDialogNetworkConfig = Field(
        default_factory=lambda: DebianDialogNetworkConfig(hostname="debian")
    )
    accounts: DebianAccountsConfig = Field(default_factory=DebianAccountsConfig)


class SlackwareDialogInstallConfig(ConfigModel):
    """Validate the complete Slackware dialog configuration."""

    driver: Literal["slackware-dialog"]
    variant: Literal[
        "1.1.2",
        "2.0",
        "2.1",
        "2.2-2.3",
        "3.0",
        "3.1-3.4",
        "3.5-4.0",
        "7.0-7.1",
        "8.0-9.0",
    ]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(default_factory=InstallLocaleConfig)
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="darkstar"))
    prompts: InstallPromptsConfig = Field(default_factory=InstallPromptsConfig)
    packages: SlackwareDialogPackagesConfig = Field(
        default_factory=SlackwareDialogPackagesConfig
    )
    bootloader: SlackwareBootloaderConfig = Field(
        default_factory=SlackwareBootloaderConfig
    )
    modem: SlackwareModemConfig = Field(default_factory=SlackwareModemConfig)
    mail: SlackwareMailConfig = Field(default_factory=SlackwareMailConfig)


class RedHatNewtInstallConfig(ConfigModel):
    """Validate the complete Red Hat Newt configuration."""

    driver: Literal["redhat-newt"]
    variant: Literal["4.0", "4.1", "4.2", "5.0", "5.1"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(default_factory=InstallLocaleConfig)
    prompts: InstallPromptsConfig = Field(default_factory=InstallPromptsConfig)
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="redhat"))
    accounts: RedHatNewtAccountsConfig = Field(
        default_factory=RedHatNewtAccountsConfig
    )
    packages: RedHatNewtPackagesConfig


class RedHatDialogInstallConfig(ConfigModel):
    """Validate the complete Red Hat dialog configuration."""

    driver: Literal["redhat-dialog"]
    variant: Literal["1.1", "2.1", "3.0.3"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(
        default_factory=lambda: InstallLocaleConfig(keymap="us.map")
    )
    prompts: InstallPromptsConfig = Field(default_factory=InstallPromptsConfig)
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="redhat"))
    packages: RedHatDialogPackagesConfig
    accounts: RedHatDialogAccountsConfig = Field(
        default_factory=RedHatDialogAccountsConfig
    )


class SysinstallInstallConfig(ConfigModel):
    """Validate the complete early Slackware Sysinstall configuration."""

    driver: Literal["slackware-sysinstall"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)


class Debian091InstallConfig(ConfigModel):
    """Validate Debian 0.91's one-off installer configuration."""

    driver: Literal["debian-091"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(
        default_factory=lambda: InstallLocaleConfig(timezone="US/Central")
    )
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="debra"))


class SlackwareTtyInstallConfig(ConfigModel):
    """Validate Slackware's one-off tty installer configuration."""

    driver: Literal["slackware-tty"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(default_factory=InstallLocaleConfig)
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="darkstar"))
    packages: SlackwareTtyPackagesConfig = Field(default_factory=SlackwareTtyPackagesConfig)


InstallConfig = Annotated[
    DebianDialogInstallConfig
    | SlackwareDialogInstallConfig
    | RedHatNewtInstallConfig
    | RedHatDialogInstallConfig
    | UnattendedInstallConfig
    | SysinstallInstallConfig
    | Debian091InstallConfig
    | SlackwareTtyInstallConfig,
    Field(discriminator="driver"),
]


class InstallConfigModel(RootModel[InstallConfig]):
    """Wrap the discriminated installer union for shared error translation."""
