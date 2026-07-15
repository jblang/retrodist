"""Resolve a selected distro config and the filesystem paths derived from it.

``Context`` is deliberately configuration-agnostic. It identifies the repo,
selected config, current command, and temporary directory, and implements the
local-then-parent file lookup shared by TOML inheritance and custom assets.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import tempfile

from .errors import ConfigError


@dataclass(frozen=True, slots=True)
class Context:
    """Identify a selected distro config and its working directories.

    Attributes:
        root: Repository root containing distro families and host libraries.
        config: Absolute path to the selected config directory.
        command: Top-level operation being executed.
        temporary: Per-command scratch directory removed by the CLI.
    """

    root: Path
    config: Path
    command: str
    temporary: Path

    @classmethod
    def create(cls, root: Path, command: str, config: str | None = None) -> "Context":
        """Resolve a user-supplied config path and create its temporary workspace.

        Relative config names are tried from the current directory first and
        then from the repository root.

        Raises:
            ConfigError: If the requested directory cannot be found.
        """
        root = root.resolve()
        candidate = Path.cwd() if config is None else Path(config)
        if config is not None and not candidate.is_dir():
            candidate = root / config
        if not candidate.is_dir():
            raise ConfigError(f"Configuration {config} doesn't exist")
        return cls(
            root=root,
            config=candidate.resolve(),
            command=command,
            temporary=Path(tempfile.mkdtemp(prefix="retro-")),
        )

    @property
    def name(self) -> str:
        """Return the config path relative to the repository when possible."""
        try:
            return str(self.config.relative_to(self.root))
        except ValueError:
            return str(self.config)

    @property
    def qemu_dir(self) -> Path:
        """Return the selected config's generated QEMU-state directory."""
        return self.config / "qemu.d"

    @property
    def extract_dir(self) -> Path:
        """Return the directory used for staged extraction output."""
        return self.qemu_dir

    @property
    def tagfile_dir(self) -> Path:
        """Return the directory containing generated Slackware tagsets."""
        return self.config / "tagfile.d"

    def find(self, name: str) -> Path | None:
        """Find a config asset locally, then in the immediate parent.

        Absolute paths are accepted unchanged when they exist. Lookup never
        continues above the immediate parent, matching ``config.toml``
        inheritance rules.
        """
        for directory in (self.config, self.config.parent):
            path = directory / name
            if path.is_file():
                return path
        return None
