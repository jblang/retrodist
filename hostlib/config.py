"""Load and validate the declarative configuration used by every host subsystem.

Configuration is read from ``config.toml`` in the selected directory and its
immediate parent. The selected config inherits parent values; child scalars and
arrays replace them, while nested tables retain keys the child does not
override. This module also resolves QEMU hardware profiles and validates
logically grouped installer settings through a driver-discriminated model.

The top-level ``download``, ``extract``, ``qemu``, ``install``, and ``postinst``
tables are consumed independently by their owning subsystem. Unknown settings
are rejected at that boundary rather than being silently ignored.
"""

from __future__ import annotations

from functools import cached_property
from pathlib import Path
import tomllib
from typing import Any, TypeVar

from pydantic import ConfigDict

from .context import Context
from .errors import ConfigError
from .schemas import (
    CommonInstallConfig,
    ConfigModel,
    DinstallInstallConfig,
    DownloadConfig,
    ExtractionConfig,
    InstallConfig,
    InstallConfigModel,
    PostinstConfig,
    PromptSequenceInstallConfig,
    PromptSequenceConfig,
    QemuConfig,
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

    ``data`` preserves the logical TOML hierarchy. Each subsystem consumes its
    validated section directly.

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
        if not self.value("install", "driver"):
            return validate(
                CommonInstallConfig,
                self.section("install", "disk"),
                "install.disk",
            )
        install = self.install
        disk = getattr(install, "disk", None)
        source = (
            disk.model_dump()
            if isinstance(disk, ConfigModel)
            else self.section("install", "disk")
        )
        if isinstance(install, DinstallInstallConfig) and install.debian.fat_filesystem:
            source["fat_filesystem"] = install.debian.fat_filesystem
        values = {key: source[key] for key in CommonInstallConfig.model_fields if key in source}
        return validate(CommonInstallConfig, values, "install")

    @cached_property
    def install(self) -> InstallConfig:
        """Return the driver-discriminated installer configuration."""
        return validate(InstallConfigModel, self.section("install"), "install").root

    @cached_property
    def prompt_sequence(self) -> PromptSequenceConfig:
        """Return the typed declarative installer action sequence."""
        install = self.install
        if not isinstance(install, PromptSequenceInstallConfig):
            raise ConfigError("Install driver is not prompt-sequence")
        return install

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
