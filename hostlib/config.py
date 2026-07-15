"""Load and validate the declarative configuration used by every host subsystem.

Configuration is read from ``config.toml`` in the selected directory and its
immediate parent. The selected config inherits parent values; child scalars and
arrays replace them, while nested tables retain keys the child does not
override. This module also resolves QEMU hardware profiles and maps logically
grouped installer settings into driver option dataclasses.

The top-level ``download``, ``extract``, ``qemu``, ``install``, and ``postinst``
tables are consumed independently by their owning subsystem. Unknown settings
are rejected at that boundary rather than being silently ignored.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from functools import cached_property
import platform
from pathlib import Path
import tomllib
import types
from typing import Any, TypeVar, Union, get_args, get_origin, get_type_hints

from .context import Context
from .errors import ConfigError

T = TypeVar("T")


def reject_unknown(table: dict[str, Any], allowed: set[str], path: str) -> None:
    """Reject keys outside the allowed set for a configuration table.

    Args:
        table: Parsed TOML table to inspect.
        allowed: Valid keys at this location.
        path: Dotted table name used in error messages.

    Raises:
        ConfigError: If ``table`` contains an unknown key.
    """
    unknown = set(table) - allowed
    if unknown:
        names = ", ".join(sorted(unknown))
        raise ConfigError(f"Unknown {path} setting(s): {names}")


def require_table(table: dict[str, Any], key: str, path: str) -> dict[str, Any]:
    """Return a nested configuration table or reject a non-table value.

    Missing tables are represented by an empty mapping so callers can apply
    defaults without distinguishing them from an explicitly empty table.
    """
    value = table.get(key, {})
    if not isinstance(value, dict):
        raise ConfigError(f"{path}.{key} must be a table")
    return value


def _overlay(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    """Overlay child TOML values on inherited parent values."""
    resolved = dict(base)
    for key, value in override.items():
        current = resolved.get(key)
        if isinstance(current, dict) and isinstance(value, dict):
            resolved[key] = _overlay(current, value)
        else:
            resolved[key] = value
    return resolved


@dataclass(frozen=True)
class RetroConfig:
    """Resolved configuration shared by all Python host subsystems.

    ``data`` preserves the logical TOML hierarchy. Installer drivers may also
    consume a flattened view of leaf settings, while the downloader, stager,
    and QEMU runtime read their own tables directly.

    Attributes:
        context: Paths and command information for the selected distro.
        data: Resolved TOML hierarchy after applying inheritance.
    """

    context: Context
    data: dict[str, Any]

    @property
    def download_dir(self) -> Path:
        """Return the directory where downloaded media is stored."""
        return (
            self.context.qemu_dir
            if self.value("download", "cdrom")
            else self.context.config / "download.d"
        )

    def section(self, *path: str) -> dict[str, Any]:
        """Return a nested configuration table, or an empty table when absent.

        Args:
            *path: Successive table names below the TOML root.
        """
        value: Any = self.data
        for part in path:
            if not isinstance(value, dict):
                return {}
            value = value.get(part, {})
        return value if isinstance(value, dict) else {}

    def value(self, *path: str, default: T | None = None) -> Any | T | None:
        """Return a nested configuration value or the supplied default.

        Args:
            *path: Successive keys below the TOML root.
            default: Value returned when any path component is absent.
        """
        value: Any = self.data
        for part in path:
            if not isinstance(value, dict) or part not in value:
                return default
            value = value[part]
        return value

    @cached_property
    def install_values(self) -> dict[str, Any]:
        """Flatten unambiguous installer option leaves for driver dataclasses.

        Logical grouping tables are discarded because drivers share flat
        option dataclasses. Duplicate leaf names are rejected rather than
        silently selecting one table's value.

        Raises:
            ConfigError: If two install tables define the same leaf name.
        """
        values: dict[str, Any] = {}
        origins: dict[str, str] = {}

        def collect(table: dict[str, Any], path: tuple[str, ...] = ()) -> None:
            """Collect installer option leaves while detecting ambiguous names."""
            for key, value in table.items():
                if isinstance(value, dict):
                    collect(value, (*path, key))
                elif key not in {"driver", "steps"}:
                    location = ".".join(("install", *path, key))
                    if key in values:
                        raise ConfigError(
                            f"Ambiguous install option {key!r} in "
                            f"{origins[key]} and {location}"
                        )
                    values[key] = value
                    origins[key] = location

        collect(self.section("install"))
        return values

    def options(self, cls: type[T]) -> T:
        """Build an installer options dataclass from matching TOML leaf keys.

        Only fields declared by ``cls`` are copied. TOML ``false`` maps to
        ``None`` for optional non-Boolean fields, allowing a prompt or feature
        inherited from a parent config to be disabled declaratively.

        Args:
            cls: Installer option dataclass to instantiate.

        Raises:
            ConfigError: If a matching TOML value has the wrong runtime type.
        """
        fields = getattr(cls, "__dataclass_fields__", {})
        annotations = get_type_hints(cls)
        values: dict[str, Any] = {}
        for key, value in self.install_values.items():
            if key not in fields:
                continue
            annotation = annotations[key]
            if (
                value is False
                and _allows_none(annotation)
                and not _matches_type(value, annotation)
            ):
                value = None
            if not _matches_type(value, annotation):
                raise ConfigError(f"Install option {key} has the wrong type")
            values[key] = value
        return cls(**values)


def _allows_none(annotation: object) -> bool:
    """Return whether a type annotation accepts None."""
    return type(None) in get_args(annotation)


def _matches_type(value: object, annotation: object) -> bool:
    """Return whether a value satisfies a supported runtime annotation."""
    origin = get_origin(annotation)
    if origin in {types.UnionType, Union}:
        return any(_matches_type(value, item) for item in get_args(annotation))
    if annotation is float:
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    if annotation is int:
        return isinstance(value, int) and not isinstance(value, bool)
    if annotation in {str, bool, type(None)}:
        return isinstance(value, annotation)
    return True


def load_config(context: Context) -> RetroConfig:
    """Resolve the selected config with values inherited from its parent.

    Args:
        context: Selected distro context whose config chain should be loaded.

    Returns:
        A semantic configuration, which may be empty for commands such as help.

    Raises:
        ConfigError: If either TOML file is syntactically invalid.
    """
    data: dict[str, Any] = {}
    for directory in (context.config.parent, context.config):
        path = directory / "config.toml"
        if not path.is_file():
            continue
        try:
            parsed = tomllib.loads(path.read_text())
        except tomllib.TOMLDecodeError as exc:
            raise ConfigError(f"Invalid TOML configuration {path}: {exc}") from exc
        data = _overlay(data, parsed)
    return RetroConfig(context, data)


@dataclass(frozen=True, slots=True)
class Profile:
    """Describe era-specific QEMU hardware defaults.

    Profiles supply conservative machine, memory, disk, network, display, and
    acceleration choices appropriate to a kernel generation. Explicit TOML
    settings always take precedence.
    """

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
    """Store validated, profile-resolved QEMU runtime settings.

    Field names describe runtime concepts. ``load_qemu_config`` maps the nested
    TOML schema into this flat structure before command construction begins.
    """

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
    forwards: list[list[int]] | None = None
    display: str = field(
        default_factory=lambda: "cocoa" if platform.system() == "Darwin" else "gtk"
    )
    acceleration: str | None = None
    vga: str | None = None
    extra: list[str] = field(default_factory=list)
    fdtype_a: str | None = "144"
    fdtype_b: str | None = "144"
    serial_aux: str | None = "null"
    boot_order: str | None = None

    def apply_profile(self) -> None:
        """Fill unset QEMU settings from the selected hardware profile."""
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


def load_qemu_config(config: RetroConfig) -> QemuConfig:
    """Build validated QEMU settings from resolved TOML and profile defaults.

    Raises:
        ConfigError: If ``[qemu]`` is absent or contains an invalid setting.
    """
    semantic = config.section("qemu")
    if not semantic:
        raise ConfigError(f"No [qemu] configuration for {config.context.name}")
    result = QemuConfig()
    _apply_toml_qemu(result, semantic)
    result.apply_profile()
    return result


def _apply_toml_qemu(config: QemuConfig, table: dict[str, Any]) -> None:
    """Apply validated qemu tables to a runtime configuration."""
    reject_unknown(
        table,
        {
            "profile",
            "system",
            "machine",
            "ram",
            "smp",
            "boot_order",
            "extra",
            "disk",
            "network",
            "display",
            "serial",
        },
        "qemu",
    )
    disk = require_table(table, "disk", "qemu")
    network = require_table(table, "network", "qemu")
    display = require_table(table, "display", "qemu")
    serial = require_table(table, "serial", "qemu")
    reject_unknown(
        disk,
        {"size", "format", "create_options", "hda_options", "floppy_a_type", "floppy_b_type"},
        "qemu.disk",
    )
    reject_unknown(network, {"device", "enabled", "forwards"}, "qemu.network")
    reject_unknown(display, {"backend", "acceleration", "vga"}, "qemu.display")
    reject_unknown(serial, {"auxiliary"}, "qemu.serial")
    values = {
        "profile": table.get("profile"),
        "system": table.get("system"),
        "machine": table.get("machine"),
        "ram": table.get("ram"),
        "smp": table.get("smp"),
        "disk_size": disk.get("size"),
        "disk_format": disk.get("format"),
        "disk_create_options": disk.get("create_options"),
        "hda_options": disk.get("hda_options"),
        "nic": network.get("device"),
        "network_enabled": network.get("enabled"),
        "forwards": network.get("forwards"),
        "display": display.get("backend"),
        "acceleration": display.get("acceleration"),
        "vga": display.get("vga"),
        "fdtype_a": disk.get("floppy_a_type"),
        "fdtype_b": disk.get("floppy_b_type"),
        "serial_aux": serial.get("auxiliary"),
        "boot_order": table.get("boot_order"),
        "extra": table.get("extra"),
    }
    for name, value in values.items():
        if value is not None:
            setattr(config, name, value)
    for name in (
        "profile",
        "system",
        "machine",
        "ram",
        "disk_size",
        "disk_format",
        "disk_create_options",
        "hda_options",
        "nic",
        "display",
        "acceleration",
        "vga",
        "fdtype_a",
        "fdtype_b",
        "serial_aux",
        "boot_order",
    ):
        value = getattr(config, name)
        if value is not None and not isinstance(value, str):
            raise ConfigError(f"qemu value for {name} must be a string")
    if not isinstance(config.smp, int) or isinstance(config.smp, bool):
        raise ConfigError("qemu.smp must be an integer")
    if not isinstance(config.network_enabled, bool):
        raise ConfigError("qemu.network.enabled must be a boolean")
    if not isinstance(config.extra, list) or not all(
        isinstance(item, str) for item in config.extra
    ):
        raise ConfigError("qemu.extra must be an array of strings")
    if config.forwards is not None and (
        not isinstance(config.forwards, list)
        or not all(
            isinstance(pair, list)
            and len(pair) == 2
            and all(isinstance(port, int) and not isinstance(port, bool) for port in pair)
            for pair in config.forwards
        )
    ):
        raise ConfigError("qemu.network.forwards must contain [host, guest] integer pairs")
