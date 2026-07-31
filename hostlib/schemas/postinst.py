"""Typed configuration for generated post-install behavior."""

from __future__ import annotations

from typing import Literal

from pydantic import Field, model_validator

from .base import ConfigModel
from .network import NetworkConfig


class PostinstNetworkConfig(NetworkConfig):
    """Add guestlib compatibility controls to canonical static networking."""

    ancient_route: int | bool | None = None
    hostname_init_set: int | bool | None = None
    gateway_hwaddr: str | None = None
    nameserver_hwaddr: str | None = None
    ifconfig_path: str | None = None
    route_path: str | None = None
    arp_path: str | None = None


class DebianPackageMountConfig(ConfigModel):
    """Describe package media that the generated guest script must mount."""

    device: str
    point: str = "/cdrom"
    filesystem: str = "iso9660"
    options: str | None = None


class DebianPackagePrompt(ConfigModel):
    """Match one package-configurator question on the automation serial port."""

    expect: str
    answer: str
    regex: bool = False


class DebianPackagesConfig(ConfigModel):
    """Select Debian packages and locate their guest installation media."""

    roots: list[str] = Field(default_factory=lambda: ["/retro/packages"], min_length=1)
    priorities: list[str] = Field(default_factory=list)
    add: list[str] = Field(default_factory=list)
    skip: list[str] = Field(default_factory=list)
    sections: dict[str, list[str]] = Field(default_factory=dict)
    prompts: list[DebianPackagePrompt] = Field(default_factory=list)
    mount: DebianPackageMountConfig | None = None


Scalar = str | int | bool


class PostinstConfig(ConfigModel):
    """Configure host-rendered post-installation behavior."""

    stages: list[Literal["packages", "modules", "network", "tty", "x11", "custom"]] = Field(
        default_factory=list
    )
    fat_filesystem: str | None = None
    custom_script: str | None = None
    debug: bool | None = None
    log: str | None = None
    reboot: bool | None = None
    modules: dict[str, Scalar] = Field(default_factory=dict)
    network: PostinstNetworkConfig = Field(default_factory=PostinstNetworkConfig)
    packages: DebianPackagesConfig = Field(default_factory=DebianPackagesConfig)
    tty: dict[str, Scalar] = Field(default_factory=dict)
    x11: dict[str, Scalar] = Field(default_factory=dict)
    custom: dict[str, Scalar] = Field(default_factory=dict)

    @model_validator(mode="after")
    def validate_stages(self) -> "PostinstConfig":
        """Validate stage-specific post-install requirements."""
        if "custom" in self.stages and self.custom_script is None:
            raise ValueError("Custom post-install stage requires postinst.custom_script")
        if self.packages.prompts and "packages" not in self.stages:
            raise ValueError("Package prompts require the packages post-install stage")
        return self

    @property
    def reboots(self) -> bool:
        """Return whether the configured guest runner finishes by rebooting."""
        return self.reboot is True or bool({"modules", "network", "tty"}.intersection(self.stages))
