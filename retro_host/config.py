from __future__ import annotations

from dataclasses import dataclass, field
import os
import platform
import re
import shlex
from pathlib import Path
from typing import Any

from .context import Context
from .errors import ConfigError


@dataclass(frozen=True, slots=True)
class Profile:
    machine: str
    ram: str
    disk_size: str
    nic: str
    vga: str | None = None
    acceleration: str | None = None


PROFILES = {
    "default": Profile("type=isapc", "16M", "500M", "ne2k_isa"),
    "linux-0.99": Profile("type=isapc", "64M", "500M", "ne2k_isa"),
    "linux-1.0": Profile("type=isapc", "64M", "512M", "ne2k_isa"),
    "linux-1.2": Profile("type=isapc", "64M", "2G", "ne2k_isa", acceleration="tcg"),
    "linux-2.0-isa": Profile("type=isapc", "64M", "2G", "ne2k_isa"),
    "linux-2.0": Profile("type=pc", "64M", "8G", "tulip", "cirrus"),
    "linux-2.2": Profile("type=pc", "64M", "8G", "tulip", "cirrus"),
    "linux-2.4": Profile("type=pc", "128M", "8G", "tulip", "std"),
}


@dataclass(slots=True)
class QemuConfig:
    profile: str = "default"
    system: str = "qemu-system-i386"
    machine: str | None = None
    ram: str | None = None
    smp: int = 1
    disk_size: str | None = None
    disk_format: str = "qcow2"
    disk_create_options: str | None = None
    hda_options: str | None = None
    nic: str | None = None
    network_enabled: bool = True
    forwards: list[tuple[int, int]] = field(default_factory=list)
    display: str = field(default_factory=lambda: "cocoa" if platform.system() == "Darwin" else "gtk")
    acceleration: str | None = None
    vga: str | None = None
    extra: list[str] = field(default_factory=list)
    fdtype_a: str | None = "144"
    fdtype_b: str | None = "144"
    serial_aux: str | None = "null"
    boot_order: str | None = None

    def apply_profile(self) -> None:
        try:
            profile = PROFILES[self.profile]
        except KeyError as exc:
            raise ConfigError(f"Unknown QEMU profile {self.profile!r}") from exc
        self.machine = self.machine or profile.machine
        self.ram = self.ram or profile.ram
        self.disk_size = self.disk_size or profile.disk_size
        self.nic = self.nic or profile.nic
        self.vga = self.vga or profile.vga
        self.acceleration = self.acceleration or profile.acceleration or "tcg"


def load_python_config(context: Context) -> QemuConfig:
    """Load a Python qemu manifest without imposing a class hierarchy on it."""
    config = QemuConfig()
    if path := context.find("qemu.py"):
        namespace: dict[str, Any] = {"config": config, "context": context}
        exec(compile(path.read_bytes(), path, "exec"), namespace)
        configured = namespace.get("config", config)
        if not isinstance(configured, QemuConfig):
            raise ConfigError(f"{path} must leave 'config' as a QemuConfig")
        config = configured
    elif path := context.find("qemu.sh"):
        _apply_legacy_assignments(config, path)
    if profile := os.getenv("QEMU_PROFILE"):
        config.profile = profile
    config.apply_profile()
    return config


_LEGACY_FIELDS: dict[str, tuple[str, Any]] = {
    "QEMU_PROFILE": ("profile", str),
    "QEMU_SYSTEM": ("system", str),
    "QEMU_MACHINE": ("machine", str),
    "QEMU_RAM": ("ram", str),
    "QEMU_SMP": ("smp", int),
    "QEMU_HD_SIZE": ("disk_size", str),
    "QEMU_HD_FORMAT": ("disk_format", str),
    "QEMU_HD_CREATE_OPTIONS": ("disk_create_options", str),
    "QEMU_HDA_OPTIONS": ("hda_options", str),
    "QEMU_NET_DEVICE": ("nic", str),
    "QEMU_DISPLAY": ("display", str),
    "QEMU_ACCEL": ("acceleration", str),
    "QEMU_VGA": ("vga", str),
    "QEMU_FDTYPE_A": ("fdtype_a", str),
    "QEMU_FDTYPE_B": ("fdtype_b", str),
    "QEMU_SERIAL_AUX": ("serial_aux", str),
    "QEMU_BOOT_ORDER": ("boot_order", str),
}


def _apply_legacy_assignments(config: QemuConfig, path: Path) -> None:
    """Read the assignment-only qemu.sh format without executing shell code."""
    assignment = re.compile(r"^([A-Z][A-Z0-9_]*)=(.*)$")
    for number, raw in enumerate(path.read_text().splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        match = assignment.match(line)
        if match is None:
            raise ConfigError(f"Unsupported Python compatibility syntax at {path}:{number}")
        name, value = match.groups()
        if name == "QEMU_NET_ENABLED":
            config.network_enabled = value.lower() not in {
                "0", "false", "no", "off", "none", "disabled"
            }
            continue
        if name not in _LEGACY_FIELDS:
            raise ConfigError(f"Unsupported QEMU setting {name} at {path}:{number}")
        field_name, convert = _LEGACY_FIELDS[name]
        words = shlex.split(value, comments=True)
        parsed = "" if not words else words[0]
        setattr(config, field_name, convert(parsed))
