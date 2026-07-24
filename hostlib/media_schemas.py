"""Typed configuration models for downloads, extraction, and guest setup."""

from __future__ import annotations

from typing import Literal

from pydantic import AliasChoices, Field, model_validator

from .schema_base import ConfigModel


class DownloadFile(ConfigModel):
    """Validate one direct download declaration."""

    path: str
    url: str


class DownloadConfig(ConfigModel):
    """Configure direct files and supported distribution mirrors."""

    cdrom: str | None = None
    files: list[DownloadFile] = Field(default_factory=list)
    slackware_mirror: str | None = None
    debian_mirror: str | None = None


class Overlay(ConfigModel):
    """Validate one staged-media overlay operation."""

    source: str
    destination: str


class ExtractionConfig(ConfigModel):
    """Configure the complete declarative media-staging plan."""

    source: str = ""
    boot_image: str | None = None
    root_image: str | None = None
    extra_images: list[str] = Field(default_factory=list)
    files: list[str] = Field(default_factory=list)
    fat_files: list[str] = Field(default_factory=list)
    package_source: str | None = None
    package_sources: list[str] = Field(default_factory=list)
    package_index: str | None = None
    package_dest: str = "packages"
    decompress: list[str] = Field(default_factory=list)
    truncate: list[str] = Field(default_factory=list)
    boot_link: str | None = None
    root_link: str | None = None
    custom_script: str | None = None
    overlays: list[Overlay] = Field(default_factory=list)

    @model_validator(mode="after")
    def package_source_forms_do_not_conflict(self) -> "ExtractionConfig":
        """Reject simultaneous use of the singular and plural package selectors."""
        if self.package_source is not None and self.package_sources:
            raise ValueError("extract.package_source and package_sources are mutually exclusive")
        return self


Scalar = str | int | bool


class NetworkConfig(ConfigModel):
    """Describe static guest networking shared by installers and guestlib."""

    hostname: str = "localhost"
    domain: str = Field(
        default="retro.net",
        validation_alias=AliasChoices("domain", "domainname"),
    )
    ip: str = Field(
        default="10.0.2.15",
        validation_alias=AliasChoices("ip", "ipaddr"),
    )
    netmask: str = "255.255.255.0"
    network: str = "10.0.2.0"
    broadcast: str = "10.0.2.255"
    gateway: str = "10.0.2.2"
    nameserver: str = "10.0.2.3"

    @model_validator(mode="before")
    @classmethod
    def aliases_do_not_conflict(cls, data: object) -> object:
        """Reject simultaneous canonical and compatibility spellings."""
        if isinstance(data, dict):
            for canonical, legacy in (("domain", "domainname"), ("ip", "ipaddr")):
                if canonical in data and legacy in data:
                    raise ValueError(
                        f"Install option {canonical!r} is set through multiple aliases: "
                        f"{canonical}, {legacy}"
                    )
        return data


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
        return self.reboot is True or bool(
            {"modules", "network", "tty"}.intersection(self.stages)
        )
