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
            {
                "default_transport": self.value("install", "default_transport"),
                "steps": self.value("install", "steps"),
            },
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
        """Flatten unambiguous installer leaves for legacy option binding.

        This view supports scalar driver fields, prompt interpolation, and
        unknown-setting checks. Nested ``ConfigModel`` fields are instead bound
        from their original logical tables by ``options``. Duplicate leaf names
        remain invalid because flattened consumers could not distinguish them.

        Raises:
            ConfigError: If two install tables define the same leaf name.
        """
        values: dict[str, Any] = {}
        self._collect_install_values(self.section("install"), values, {})
        return values

    def _collect_install_values(
        self,
        table: dict[str, Any],
        values: dict[str, Any],
        origins: dict[str, str],
        path: tuple[str, ...] = (),
    ) -> None:
        """Collect installer leaves recursively and reject ambiguous names."""
        for key, value in table.items():
            if isinstance(value, dict):
                self._collect_install_values(value, values, origins, (*path, key))
                continue
            if key in {"driver", "steps"}:
                continue
            location = ".".join(("install", *path, key))
            if key in values:
                raise ConfigError(
                    f"Ambiguous install option {key!r} in {origins[key]} and {location}"
                )
            values[key] = value
            origins[key] = location

    def options(self, cls: type[T]) -> T:
        """Build an installer options model from matching TOML leaf keys.

        Nested ``ConfigModel`` fields retain their corresponding logical table
        and are overlaid on the option model's defaults. Other install tables
        remain available through the legacy flattened leaf view. TOML ``false``
        maps to ``None`` for optional non-Boolean fields, allowing an inherited
        prompt or feature to be disabled declaratively.

        Args:
            cls: Installer option model to instantiate.

        Raises:
            ConfigError: If a matching TOML value has the wrong runtime type.
        """
        values = self._option_values(getattr(cls, "model_fields", {}))
        try:
            return cls.model_validate(values)
        except ValidationError as exc:
            key = str(exc.errors()[0]["loc"][0])
            raise ConfigError(f"Install option {key} has the wrong type") from exc

    def _option_values(self, fields: dict[str, Any]) -> dict[str, Any]:
        """Collect nested tables and compatible flattened leaves for an option model."""
        values, nested = self._nested_option_values(fields)
        for key, value in self.install_values.items():
            if key not in fields or key in nested:
                continue
            annotation = fields[key].annotation
            if value is False and _allows_none(annotation) and bool not in get_args(annotation):
                value = None
            values[key] = value
        return values

    def _nested_option_values(self, fields: dict[str, Any]) -> tuple[dict[str, Any], set[str]]:
        """Overlay logical install tables on defaults for nested option fields.

        Values remain dictionaries here so the outer option model performs all
        nested validation inside ``options``'s ``ConfigError`` boundary.
        """
        values: dict[str, Any] = {}
        nested: set[str] = set()
        for key, field in fields.items():
            annotation = field.annotation
            if not isinstance(annotation, type) or not issubclass(annotation, ConfigModel):
                continue
            nested.add(key)
            default = field.get_default(call_default_factory=True)
            base = default.model_dump() if isinstance(default, ConfigModel) else {}
            table = self.section("install", key)
            selected = self._nested_table_values(annotation, table)
            values[key] = {**base, **selected}
        return values, nested

    @staticmethod
    def _nested_table_values(model: type[ConfigModel], table: dict[str, Any]) -> dict[str, Any]:
        """Normalize declared nested fields and reject conflicting aliases."""
        selected: dict[str, Any] = {}
        for name, field in model.model_fields.items():
            aliases = getattr(field.validation_alias, "choices", ())
            candidates = (name, *(alias for alias in aliases if isinstance(alias, str)))
            present = list(
                dict.fromkeys(candidate for candidate in candidates if candidate in table)
            )
            if len(present) > 1:
                raise ConfigError(
                    f"Install option {name!r} is set through multiple aliases: "
                    f"{', '.join(present)}"
                )
            if present:
                selected[name] = table[present[0]]
        return selected


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
