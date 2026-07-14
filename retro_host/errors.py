class RetroError(Exception):
    """An expected, user-facing Retro failure."""


class ConfigError(RetroError):
    """A missing or invalid distro configuration."""


class CommandError(RetroError):
    """An external command failed."""

