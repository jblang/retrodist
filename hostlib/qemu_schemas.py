"""Typed configuration models for QEMU hardware and runtime settings."""

from __future__ import annotations

import platform
from typing import Annotated

from pydantic import ConfigDict, Field, model_validator

from .schema_base import ConfigModel


class QemuDisk(ConfigModel):
    """Validate the nested QEMU disk table."""

    size: str | None = None
    format: str = "qcow2"
    create_options: str | None = None
    hda_options: str | None = None
    floppy_a_type: str | None = "144"
    floppy_b_type: str | None = "144"


PortForward = Annotated[list[int], Field(min_length=2, max_length=2)]


class QemuNetwork(ConfigModel):
    """Validate the nested QEMU network table."""

    device: str | None = None
    enabled: bool = True
    forwards: list[PortForward] | None = None


class QemuDisplay(ConfigModel):
    """Validate the nested QEMU display table."""

    backend: str = Field(
        default_factory=lambda: "cocoa" if platform.system() == "Darwin" else "gtk"
    )
    acceleration: str | None = None
    vga: str | None = None


class QemuSerial(ConfigModel):
    """Validate the nested QEMU serial table."""

    auxiliary: str | None = "null"


class QemuProfile(ConfigModel):
    """Store one named set of era-specific QEMU hardware defaults."""

    model_config = ConfigDict(strict=True, extra="forbid", frozen=True)

    machine: str
    ram: str
    disk_size: str
    nic: str
    vga: str | None = None
    acceleration: str | None = None


QEMU_PROFILES = {
    "default": QemuProfile(machine="type=isapc", ram="16M", disk_size="500M", nic="ne2k_isa"),
    "linux-0.99": QemuProfile(machine="type=isapc", ram="64M", disk_size="500M", nic="ne2k_isa"),
    "linux-1.0": QemuProfile(machine="type=isapc", ram="64M", disk_size="512M", nic="ne2k_isa"),
    "linux-1.2": QemuProfile(
        machine="type=isapc",
        ram="64M",
        disk_size="2G",
        nic="ne2k_isa",
        acceleration="tcg",
    ),
    "linux-2.0-isa": QemuProfile(machine="type=isapc", ram="64M", disk_size="2G", nic="ne2k_isa"),
    "linux-2.0": QemuProfile(
        machine="type=pc", ram="64M", disk_size="8G", nic="tulip", vga="cirrus"
    ),
    "linux-2.2": QemuProfile(
        machine="type=pc", ram="64M", disk_size="8G", nic="tulip", vga="cirrus"
    ),
    "linux-2.4": QemuProfile(
        machine="type=pc", ram="128M", disk_size="8G", nic="tulip", vga="std"
    ),
}


class QemuConfig(ConfigModel):
    """Validate and resolve the nested QEMU runtime configuration."""

    profile: str = "default"
    system: str = "qemu-system-i386"
    machine: str | None = None
    ram: str | None = None
    smp: int = 1
    boot_order: str | None = None
    extra: list[str] = Field(default_factory=list)
    disk: QemuDisk = Field(default_factory=QemuDisk)
    network: QemuNetwork = Field(default_factory=QemuNetwork)
    display: QemuDisplay = Field(default_factory=QemuDisplay)
    serial: QemuSerial = Field(default_factory=QemuSerial)

    @model_validator(mode="after")
    def apply_profile(self) -> "QemuConfig":
        """Fill unset hardware settings from the selected QEMU profile."""
        try:
            profile = QEMU_PROFILES[self.profile]
        except KeyError as exc:
            raise ValueError(f"Unknown QEMU profile {self.profile!r}") from exc
        self.machine = self.machine or profile.machine
        self.ram = self.ram or profile.ram
        self.disk.size = self.disk.size or profile.disk_size
        self.network.device = self.network.device or profile.nic
        self.display.vga = self.display.vga or profile.vga
        self.display.acceleration = self.display.acceleration or profile.acceleration or "tcg"
        return self
