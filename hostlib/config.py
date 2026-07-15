"""Load and validate the declarative configuration used by every host subsystem.

Configuration is read from ``config.toml`` in the selected directory and its
immediate parent. The selected config inherits parent values; child scalars and
arrays replace them, while nested tables retain keys the child does not
override. This module also resolves QEMU hardware profiles and maps logically
grouped installer settings into typed driver option models.

The top-level ``download``, ``extract``, ``qemu``, ``install``, and ``postinst``
tables are consumed independently by their owning subsystem. Unknown settings
are rejected at that boundary rather than being silently ignored.
"""

from __future__ import annotations

from functools import cached_property
from pathlib import Path
import tomllib
from typing import Any, TypeVar, get_args

from pydantic import ConfigDict, ValidationError

from .context import Context
from .errors import ConfigError
from .schemas import (
    CommonInstallConfig,
    ConfigModel,
    DinstallBootConfig,
    DownloadConfig,
    ExtractionConfig,
    InstallDriverConfig,
    PkgtoolBootConfig,
    PostinstConfig,
    PromptSequenceConfig,
    QemuConfig,
    RedhatFlowConfig,
    UnattendedInstallConfig,
    validate,
)

T = TypeVar("T")


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


class RetroConfig(ConfigModel):
    """Resolved configuration shared by all Python host subsystems.

    ``data`` preserves the logical TOML hierarchy. Installer drivers may also
    consume a flattened view of leaf settings, while the downloader, stager,
    and QEMU runtime read their own tables directly.

    Attributes:
        context: Paths and command information for the selected distro.
        data: Resolved TOML hierarchy after applying inheritance.
    """

    # Context is runtime state rather than configuration input. Keeping it
    # unconstrained also permits the lightweight context doubles used by
    # callers and tests.
    context: Any
    data: dict[str, Any]

    model_config = ConfigDict(
        strict=True,
        extra="forbid",
        frozen=True,
        arbitrary_types_allowed=True,
    )

    @property
    def download_dir(self) -> Path:
        """Return the directory where downloaded media is stored."""
        return self.context.qemu_dir if self.download.cdrom else self.context.config / "download.d"

    @cached_property
    def download(self) -> DownloadConfig:
        """Return the validated download configuration."""
        return validate(DownloadConfig, self.section("download"), "download")

    @cached_property
    def extraction(self) -> ExtractionConfig:
        """Return the validated media-extraction configuration."""
        return validate(ExtractionConfig, self.section("extract"), "extract")

    @cached_property
    def postinst(self) -> PostinstConfig:
        """Return the validated post-installation configuration."""
        return validate(PostinstConfig, self.section("postinst"), "postinst")

    @cached_property
    def qemu(self) -> QemuConfig:
        """Return the validated and profile-resolved QEMU configuration."""
        if not self.section("qemu"):
            raise ConfigError(f"No [qemu] configuration for {self.context.name}")
        return validate(QemuConfig, self.section("qemu"), "qemu")

    @cached_property
    def install_common(self) -> CommonInstallConfig:
        """Return shared installer paths and partition defaults."""
        fields = CommonInstallConfig.model_fields
        values = {key: value for key, value in self.install_values.items() if key in fields}
        return validate(CommonInstallConfig, values, "install")

    @cached_property
    def install_driver(self) -> InstallDriverConfig:
        """Return the selected installer driver."""
        return validate(
            InstallDriverConfig,
            {"driver": self.value("install", "driver")},
            "install",
        )

    @cached_property
    def dinstall_boot(self) -> DinstallBootConfig:
        """Return Debian installer boot controls."""
        return validate(
            DinstallBootConfig,
            self.value("install", "boot", default={}),
            "install.boot",
        )

    @cached_property
    def pkgtool_boot(self) -> PkgtoolBootConfig:
        """Return Slackware installer boot controls."""
        return validate(
            PkgtoolBootConfig,
            self.value("install", "boot", default={}),
            "install.boot",
        )

    @cached_property
    def redhat_flow(self) -> RedhatFlowConfig:
        """Return the selected early Red Hat installer flow."""
        return validate(
            RedhatFlowConfig,
            self.value("install", "redhat", default={}),
            "install.redhat",
        )

    @cached_property
    def unattended_install(self) -> UnattendedInstallConfig:
        """Return unattended Red Hat lifecycle settings."""
        install = self.section("install")
        values = {
            key: install.get(key, {}) for key in ("boot", "completion", "accounts", "prompts")
        }
        return validate(UnattendedInstallConfig, values, "install")

    @cached_property
    def prompt_sequence(self) -> PromptSequenceConfig:
        """Return the typed declarative installer action sequence."""
        return validate(
            PromptSequenceConfig,
            {"steps": self.value("install", "steps")},
            "install",
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
        """Flatten unambiguous installer option leaves for driver models.

        Logical grouping tables are discarded because drivers share flat
        option models. Duplicate leaf names are rejected rather than
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
        """Build an installer options model from matching TOML leaf keys.

        Only fields declared by ``cls`` are copied. TOML ``false`` maps to
        ``None`` for optional non-Boolean fields, allowing a prompt or feature
        inherited from a parent config to be disabled declaratively.

        Args:
            cls: Installer option model to instantiate.

        Raises:
            ConfigError: If a matching TOML value has the wrong runtime type.
        """
        fields = getattr(cls, "model_fields", {})
        values: dict[str, Any] = {}
        for key, value in self.install_values.items():
            if key not in fields:
                continue
            annotation = fields[key].annotation
            if value is False and _allows_none(annotation) and bool not in get_args(annotation):
                value = None
            values[key] = value
        try:
            return cls.model_validate(values)
        except ValidationError as exc:
            key = str(exc.errors()[0]["loc"][0])
            raise ConfigError(f"Install option {key} has the wrong type") from exc


def _allows_none(annotation: object) -> bool:
    """Return whether a type annotation accepts None."""
    return type(None) in get_args(annotation)


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
    return RetroConfig(context=context, data=data)


def load_qemu_config(config: RetroConfig) -> QemuConfig:
    """Build validated QEMU settings from resolved TOML and profile defaults.

    Raises:
        ConfigError: If ``[qemu]`` is absent or contains an invalid setting.
    """
    return config.qemu
