"""Typed configuration for Red Hat installer drivers."""

from __future__ import annotations

from typing import Literal

from pydantic import Field

from .base import ConfigModel
from .install import InstallDiskConfig, InstallLocaleConfig, InstallPromptsConfig
from .network import NetworkConfig


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


class RedHatNewtInstallConfig(ConfigModel):
    """Validate the complete Red Hat Newt configuration."""

    driver: Literal["redhat-newt"]
    variant: Literal["4.0", "4.1", "4.2", "5.0", "5.1"]
    disk: InstallDiskConfig = Field(default_factory=InstallDiskConfig)
    locale: InstallLocaleConfig = Field(default_factory=InstallLocaleConfig)
    prompts: InstallPromptsConfig = Field(default_factory=InstallPromptsConfig)
    network: NetworkConfig = Field(default_factory=lambda: NetworkConfig(hostname="redhat"))
    accounts: RedHatNewtAccountsConfig = Field(default_factory=RedHatNewtAccountsConfig)
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
    accounts: RedHatDialogAccountsConfig = Field(default_factory=RedHatDialogAccountsConfig)
