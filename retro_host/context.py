from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import tempfile

from .errors import ConfigError


@dataclass(frozen=True, slots=True)
class Context:
    root: Path
    config: Path
    command: str
    temporary: Path

    @classmethod
    def create(
        cls, root: Path, command: str, config: str | None = None
    ) -> "Context":
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
        try:
            return str(self.config.relative_to(self.root))
        except ValueError:
            return str(self.config)

    @property
    def qemu_dir(self) -> Path:
        return self.config / "qemu.d"

    @property
    def extract_dir(self) -> Path:
        return self.qemu_dir

    @property
    def download_dir(self) -> Path:
        return self.qemu_dir if self.find("cdrom.txt") else self.config / "download.d"

    @property
    def tagfile_dir(self) -> Path:
        return self.config / "tagfile.d"

    def find(self, name: str) -> Path | None:
        """Find a config file locally, then in the immediate parent."""
        for directory in (self.config, self.config.parent):
            path = directory / name
            if path.is_file():
                return path
        return None

