"""Typed configuration for Slackware installer drivers."""

from __future__ import annotations

from typing import Literal

from pydantic import Field

from .base import ConfigModel
from .install import InstallDiskConfig, InstallLocaleConfig, InstallPromptsConfig
from .network import NetworkConfig


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


class SlackwareTtyPackagesConfig(ConfigModel):
    """Select package sets used by Slackware's early tty setup program."""

    package_sets: str = "A AP D E F IV N TCL OI OOP X XAP XD XV Y"


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
    packages: SlackwareDialogPackagesConfig = Field(default_factory=SlackwareDialogPackagesConfig)
    bootloader: SlackwareBootloaderConfig = Field(default_factory=SlackwareBootloaderConfig)
    modem: SlackwareModemConfig = Field(default_factory=SlackwareModemConfig)
    mail: SlackwareMailConfig = Field(default_factory=SlackwareMailConfig)


class SysinstallInstallConfig(ConfigModel):
    """Validate the complete early Slackware Sysinstall configuration."""

    driver: Literal["slackware-sysinstall"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)


class SlackwareTtyInstallConfig(ConfigModel):
    """Validate Slackware's one-off tty installer configuration."""

    driver: Literal["slackware-tty"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(default_factory=InstallLocaleConfig)
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="darkstar"))
    packages: SlackwareTtyPackagesConfig = Field(default_factory=SlackwareTtyPackagesConfig)
