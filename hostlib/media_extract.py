"""Extract selected files and package trees from supported source media."""

from __future__ import annotations

import fnmatch
from pathlib import Path, PurePosixPath
import shutil
import tarfile
import zipfile

import py7zr

from .config import RetroConfig
from .context import Context
from . import ConfigError
from .iso import Iso
from .schemas.media import ExtractionConfig


def link_media(source: Path | str, destination: Path) -> None:
    """Create a conventional staged-media link to an existing source."""
    source = Path(source)
    target = source if source.is_absolute() else destination.parent / source
    if target.absolute() == destination.absolute():
        return
    if not target.exists():
        raise ConfigError(f"Link source not found: {source}")
    destination.unlink(missing_ok=True)
    destination.symlink_to(source)


def safe_child(directory: Path, relative: Path) -> Path:
    """Resolve a child path and reject absolute or traversal paths."""
    target = (directory / relative).resolve()
    if not target.is_relative_to(directory.resolve()):
        raise ConfigError(f"Archive path escapes destination: {relative}")
    return target


def _selected_archive_members(
    names: list[str], spec: ExtractionConfig, files: list[str]
) -> list[str]:
    """Select regular archive members required by declarative staging."""
    selected: set[str] = set()
    for pattern in [*files, *spec.fat_files]:
        matches = [name for name in names if fnmatch.fnmatch(name, pattern)]
        if not matches:
            raise ConfigError(f"Archive path not found: {pattern}")
        selected.update(matches)
    for package_source in spec.package_paths:
        prefix = package_source.strip("/")
        matches = [name for name in names if name.strip("/").startswith(f"{prefix}/")]
        if not matches:
            raise ConfigError(f"Archive path not found: {package_source}")
        selected.update(matches)
    for name in selected:
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts:
            raise ConfigError(f"Archive path escapes destination: {name}")
    return sorted(selected)


def _validate_source_path(value: str) -> None:
    """Reject selectors that escape the configured extraction source."""
    path = Path(value)
    if path.is_absolute() or ".." in path.parts or path == Path("."):
        raise ConfigError(f"Source path escapes extraction source: {value}")


def _copy_matches(source: Path, pattern: str, destination: Path) -> None:
    """Copy files matching a source path or glob into a destination."""
    matches = [match for match in source.glob(pattern) if match.is_file()]
    if not matches:
        raise ConfigError(f"Source path not found: {pattern}")
    destination.mkdir(parents=True, exist_ok=True)
    for match in matches:
        shutil.copy2(match, destination / match.name)


class MediaExtractor:
    """Stage selected install media from an ISO, archive, or directory."""

    def __init__(self, context: Context, config: RetroConfig) -> None:
        """Bind extraction to the selected configuration and staging directory."""
        self.context = context
        self.config = config
        self.directory = context.qemu_dir

    def stage(self, spec: ExtractionConfig) -> None:
        """Stage selected source media before custom extraction hooks run."""
        source = Path(spec.source)
        if not source.is_absolute():
            source = self.config.download_dir / source
        files = spec.staged_files
        for path in [*files, *spec.fat_files]:
            _validate_source_path(path)
        for package_source in spec.package_paths:
            _validate_source_path(package_source)
        if source.suffix.lower() == ".iso":
            self._stage_iso(source, spec, files)
        elif source.is_dir():
            self._stage_directory(source, spec, files)
        elif (
            tarfile.is_tarfile(source)
            or source.suffix.lower() == ".7z"
            or zipfile.is_zipfile(source)
        ):
            self._stage_archive(source, spec, files)
        else:
            raise ConfigError(f"Unsupported extraction source: {source.name}")

    def _stage_archive(self, source: Path, spec: ExtractionConfig, files: list[str]) -> None:
        """Extract selected regular archive members, then stage the directory."""
        temporary = self.context.temporary / "archive"
        shutil.rmtree(temporary, ignore_errors=True)
        temporary.mkdir()
        if tarfile.is_tarfile(source):
            with tarfile.open(source) as archive:
                members = {
                    member.name: member for member in archive.getmembers() if member.isfile()
                }
                selected = _selected_archive_members(list(members), spec, files)
                archive.extractall(
                    temporary,
                    (members[name] for name in selected),
                    filter="data",
                )
        elif source.suffix.lower() == ".7z":
            with py7zr.SevenZipFile(source, "r") as archive:
                names = [entry.filename for entry in archive.list() if entry.is_file]
                selected = _selected_archive_members(names, spec, files)
                archive.extract(path=temporary, targets=selected)
        else:
            with zipfile.ZipFile(source) as archive:
                names = [entry.filename for entry in archive.infolist() if not entry.is_dir()]
                selected = _selected_archive_members(names, spec, files)
                archive.extractall(temporary, selected)
        self._stage_directory(temporary, spec, files)

    def _stage_iso(self, source: Path, spec: ExtractionConfig, files: list[str]) -> None:
        """Stage selected files and a package tree from an ISO image."""
        link_media(source, self.directory / "install.iso")
        with Iso(source) as image:
            for item in files:
                image.extract_files(item, self.directory)
            for item in spec.fat_files:
                image.extract_files(item, self.directory / "fat")
            for package_source in spec.package_paths:
                image.extract_tree(package_source, self._package_destination(spec))

    def _stage_directory(self, source: Path, spec: ExtractionConfig, files: list[str]) -> None:
        """Stage selected files and packages from an extracted directory."""
        for item in files:
            _copy_matches(source, item, self.directory)
        for item in spec.fat_files:
            _copy_matches(source, item, self.directory / "fat")
        for package_source in spec.package_paths:
            shutil.copytree(
                safe_child(source, Path(package_source)),
                self._package_destination(spec),
                dirs_exist_ok=True,
                ignore=shutil.ignore_patterns(".complete"),
            )

    def _package_destination(self, spec: ExtractionConfig) -> Path:
        """Resolve the configured package destination beneath the FAT tree."""
        return safe_child(self.directory / "fat", Path(spec.package_dest))
