"""Python host runtime for downloading, staging, and installing retro distros.

The ``retro`` workflow resolves one ``RetroConfig`` and passes it through
``Downloader``, ``MediaStager``, and ``QemuRuntime``. Most host work is
synchronous. A live VM introduces one event loop for the QEMU process, QMP,
serial input, and VGA polling. ``QemuSession`` exposes those controls as a
linear synchronous scripting facade from a worker thread. Installer drivers
consume that API and receive their configuration separately.

Configuration is declarative and grouped by subsystem. Shared family drivers
and focused one-off drivers live under ``hostlib.install`` while
release-specific values remain in TOML.
"""


class RetroError(Exception):
    """An expected, user-facing Retro failure."""


class ConfigError(RetroError):
    """A missing or invalid distro configuration."""


class CommandError(RetroError):
    """An external command failed."""
