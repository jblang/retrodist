"""Typed configuration for Debian installer drivers."""

from __future__ import annotations

from typing import Literal

from pydantic import Field

from .base import ConfigModel
from .install import InstallDiskConfig, InstallLocaleConfig
from .network import NetworkConfig


class DebianDialogNetworkConfig(NetworkConfig):
    """Add Debian installer module controls to static networking."""

    net_module: str | None = None
    net_module_args: str = ""


class DebianAccountsConfig(ConfigModel):
    """Configure Debian Dinstall accounts."""

    root_password: str = "password1"
    user: str = "debian"
    user_password: str = "password1"


class DebianDialogBootConfig(ConfigModel):
    """Configure Debian installer boot and root-disk prompts."""

    prompt: str = "boot:"
    command: str = ""
    root_prompt: str | None = None
    root_image: str = "root.img"


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


class Debian091InstallConfig(ConfigModel):
    """Validate Debian 0.91's one-off installer configuration."""

    driver: Literal["debian-091"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(
        default_factory=lambda: InstallLocaleConfig(timezone="US/Central")
    )
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="debra"))
