"""Typed configuration models for QEMU hardware and runtime settings."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Annotated, Literal

from pydantic import Field
from .schema_base import ConfigModel


class QemuDisk(ConfigModel):
    """Validate the nested QEMU disk table."""

    size: str | None = None


PortForward = Annotated[list[int], Field(min_length=2, max_length=2)]


class QemuNetwork(ConfigModel):
    """Validate the nested QEMU network table."""

    device: str | None = None
    enabled: bool = True
    forwards: list[PortForward] | None = None


class QemuSerial(ConfigModel):
    """Validate the nested QEMU serial table."""

    auxiliary: str | None = "null"


@dataclass(frozen=True, slots=True)
class QemuProfile:
    """Store one named set of era-specific QEMU hardware defaults."""

    machine: str
    ram: str
    disk_size: str
    nic: str
    vga: str | None = None


QEMU_PROFILES = {
    "default": QemuProfile(machine="type=isapc", ram="16M", disk_size="500M", nic="ne2k_isa"),
    "linux-0.99": QemuProfile(machine="type=isapc", ram="64M", disk_size="500M", nic="ne2k_isa"),
    "linux-1.0": QemuProfile(machine="type=isapc", ram="64M", disk_size="512M", nic="ne2k_isa"),
    "linux-1.2": QemuProfile(
        machine="type=isapc",
        ram="64M",
        disk_size="2G",
        nic="ne2k_isa",
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
    """Validate the distro-selectable QEMU runtime settings."""

    profile: Literal[
        "default",
        "linux-0.99",
        "linux-1.0",
        "linux-1.2",
        "linux-2.0-isa",
        "linux-2.0",
        "linux-2.2",
        "linux-2.4",
    ] = "default"
    disk: QemuDisk = QemuDisk()
    network: QemuNetwork = QemuNetwork()
    serial: QemuSerial = QemuSerial()
