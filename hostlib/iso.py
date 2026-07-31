"""Provide case-tolerant file access to ISO images."""

from __future__ import annotations

import fnmatch
from pathlib import Path, PurePosixPath

from . import CommandError, ConfigError


def _key(path: str) -> str:
    """Normalize an ISO path for case-insensitive lookup."""
    return "/" + "/".join(
        part.split(";", 1)[0].lower() for part in PurePosixPath(path).parts if part != "/"
    )


class Iso:
    """Access an ISO through its richest available namespace.

    Rock Ridge is preferred, followed by Joliet and plain ISO9660. A normalized
    path index hides namespace casing and version suffix differences while
    preserving original names for extraction.
    """

    def __init__(self, path: Path) -> None:
        """Open an ISO image and index its preferred namespace."""
        try:
            import pycdlib
        except ImportError as exc:
            raise CommandError("pycdlib is required for ISO extraction") from exc
        self.image = pycdlib.PyCdlib()
        self.image.open(str(path))
        if self.image.has_rock_ridge():
            self.argument = "rr_path"
        elif self.image.has_joliet():
            self.argument = "joliet_path"
        else:
            self.argument = "iso_path"
        self.paths: dict[str, tuple[str, bool]] = {}
        for base, directories, files in self.image.walk(**{self.argument: "/"}):
            for names, directory in ((directories, True), (files, False)):
                for name in names:
                    source = f"{base.rstrip('/')}/{name}"
                    self.paths[_key(source)] = (source, directory)

    def __enter__(self) -> "Iso":
        """Return this open ISO image."""
        return self

    def __exit__(self, *_: object) -> None:
        """Close the ISO image when its context ends."""
        self.image.close()

    def extract_file(self, source: str, destination: Path) -> None:
        """Extract one file from the ISO namespace."""
        try:
            actual, directory = self.paths[_key(source)]
        except KeyError as exc:
            raise ConfigError(f"ISO path not found: {source}") from exc
        if directory:
            raise ConfigError(f"Expected ISO file, found directory: {source}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        self.image.get_file_from_iso(local_path=str(destination), **{self.argument: actual})

    def extract_files(self, source: str, destination: Path) -> None:
        """Extract all files matching a path or glob pattern."""
        matches = [
            actual
            for key, (actual, directory) in self.paths.items()
            if not directory and fnmatch.fnmatch(key, _key(source))
        ]
        if not matches:
            raise ConfigError(f"ISO path not found: {source}")
        wildcard = any(character in source for character in "*?[")
        for actual in matches:
            name = PurePosixPath(actual if wildcard else source).name.split(";", 1)[0]
            self.extract_file(actual, destination / name)

    def extract_tree(self, source: str, destination: Path) -> None:
        """Extract a complete directory tree from the ISO."""
        prefix = _key(source).rstrip("/")
        matches = [
            (key, actual)
            for key, (actual, directory) in self.paths.items()
            if not directory and (key == prefix or key.startswith(f"{prefix}/"))
        ]
        if not matches:
            raise ConfigError(f"ISO directory not found: {source}")
        for key, actual in matches:
            relative = key[len(prefix) :].lstrip("/")
            target = destination / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            self.image.get_file_from_iso(local_path=str(target), **{self.argument: actual})
