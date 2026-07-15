"""Materialize the source media declared by a distro's ``[download]`` table.

The downloader supports direct URL/path pairs, official Slackware mirrors,
archived Debian release trees, and references to shared CD-ROM configs. It is
idempotent at the file level and traverses HTTP directory indexes with fsspec.
"""

from __future__ import annotations

import fnmatch
import logging
from pathlib import Path, PurePosixPath
import re
import sys
from typing import TextIO
import urllib.parse

import fsspec
from fsspec.callbacks import Callback
from fsspec.spec import AbstractFileSystem

from .context import Context
from .config import RetroConfig, load_config
from .errors import ConfigError
from .schemas import DownloadConfig

log = logging.getLogger(__name__)


def _size(value: int) -> str:
    """Format a byte count compactly for transfer progress."""
    amount = float(value)
    for unit in ("B", "KiB", "MiB", "GiB"):
        if amount < 1024 or unit == "GiB":
            precision = 0 if unit == "B" or amount >= 100 else 1
            return f"{amount:.{precision}f} {unit}"
        amount /= 1024
    raise AssertionError("unreachable")


def _mirror_identifier(value: str, setting: str) -> str:
    """Validate a mirror identifier before using it in URLs or local paths."""
    if value in {".", ".."} or re.fullmatch(r"[A-Za-z0-9._+-]+", value) is None:
        raise ConfigError(f"download.{setting} contains an unsafe release name: {value}")
    return value


class DownloadProgress(Callback):
    """Render fsspec transfer progress on an interactive terminal."""

    def __init__(self, label: str, stream: TextIO | None = None, width: int = 20) -> None:
        """Initialize a progress bar for one destination filename."""
        self.stream = stream or sys.stderr
        self.width = width
        example = f"Downloading : [{'#' * width}] {1:6.1%}  9999 GiB/9999 GiB"
        label_width = max(1, 80 - len(example))
        self.label = (
            label if len(label) <= label_width else label[: max(0, label_width - 3)] + "..."
        )
        self.enabled = self.stream.isatty()
        self.rendered = False
        self.updates = 0
        super().__init__()

    def call(self, hook_name: str | None = None, **kwargs: object) -> None:
        """Update the bar after fsspec changes its byte counters."""
        if not self.enabled:
            return
        self.updates += 1
        downloaded = self.value
        if self.size is not None and self.size > 0:
            downloaded = min(downloaded, self.size)
            fraction = downloaded / self.size
            filled = round(self.width * fraction)
            bar = "#" * filled + "-" * (self.width - filled)
            status = f"[{bar}] {fraction:6.1%}  {_size(downloaded)}/{_size(self.size)}"
        else:
            position = self.updates % self.width
            bar = "-" * position + ">" + "-" * (self.width - position - 1)
            status = f"[{bar}]  {_size(downloaded)}"
        self.stream.write(f"\rDownloading {self.label}: {status}")
        self.stream.flush()
        self.rendered = True

    def close(self) -> None:
        """Finish the terminal line if progress was displayed."""
        if self.rendered:
            self.stream.write("\n")
            self.stream.flush()
            self.rendered = False


class Downloader:
    """Download all media declared by a distro config.

    CD-ROM references load the shared disc configuration and link its ISO files
    into the selected config's ``qemu.d``. Ordinary downloads remain under
    ``download.d``.
    """

    def __init__(self, context: Context, config: RetroConfig) -> None:
        """Initialize a downloader for the selected distro configuration."""
        self.context = context
        self.config = config
        self._http: AbstractFileSystem | None = None

    @property
    def http(self) -> AbstractFileSystem:
        """Return the shared fsspec HTTP filesystem for this command."""
        if self._http is None:
            self._http = fsspec.filesystem("http", simple_links=False)
        return self._http

    def run(self) -> None:
        """Download all media sources required by the selected config.

        Raises:
            ConfigError: If the schema or a CD-ROM reference is invalid.
            OSError: If an HTTP listing or transfer fails.
        """
        download = self.config.download
        name = download.cdrom
        if name:
            directory = self.context.root / "cdrom" / name
            if not directory.is_dir():
                raise ConfigError(f"CD-ROM configuration does not exist: {name}")
            cd_context = Context(self.context.root, directory, "download", self.context.temporary)
            shared = load_config(cd_context).download
            self._download(shared, directory / "download.d")
            self.context.qemu_dir.mkdir(parents=True, exist_ok=True)
            for image in (directory / "download.d").glob("*.iso"):
                target = self.context.qemu_dir / image.name
                target.unlink(missing_ok=True)
                target.symlink_to(image)
        self._download(download, self.config.download_dir)

    def _download(self, download: DownloadConfig, destination: Path) -> None:
        """Download one config's direct files and mirror sources."""
        destination.mkdir(parents=True, exist_ok=True)
        for item in download.files:
            filename = item.path
            url = item.url
            path = PurePosixPath(filename)
            if path.is_absolute() or ".." in path.parts:
                raise ConfigError(f"Unsafe download path in config.toml: {filename}")
            target = destination / path
            if target.is_file():
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            log.info("Downloading %s", filename)
            self._retrieve(url, target)
        if mirror := download.slackware_mirror:
            self._slackware(mirror, destination)
        if mirror := download.debian_mirror:
            self._debian(mirror, destination)

    def _slackware(self, version: str, destination: Path) -> None:
        """Mirror the requested Slackware release tree."""
        version = _mirror_identifier(version, "slackware_mirror")
        target = destination / f"slackware-{version}"
        self._mirror_tree(
            f"http://mirrors.slackware.com/slackware/slackware-{version}/",
            target,
            reject=("*.md5*", "*.meta4", "*.sha*", "*mirror*", "*index*"),
        )

    def _debian(self, release: str, destination: Path) -> None:
        """Mirror the installer files required by a Debian release."""
        release = _mirror_identifier(release, "debian_mirror")
        root = f"https://archive.debian.org/debian/dists/{release}"
        base = destination / release
        if release != "Debian-0.93R6":
            root += "/main"
            base /= "main"
        assets = {
            "Debian-0.93R6": (["README.DEBIAN", "Contents"], ["ms-dos", "disks"]),
            "buzz": (["README", "Contents"], ["msdos-i386", "disks-i386"]),
            "rex": (["README", "Contents"], ["msdos-i386", "disks-i386"]),
            "bo": (["README", "Contents-i386.gz"], ["msdos-i386", "disks-i386"]),
        }
        files, directories = assets.get(
            release, (["Contents-i386.gz"], ["binary-i386", "disks-i386"])
        )
        base.mkdir(parents=True, exist_ok=True)
        for name in files:
            target = base / name
            if not target.is_file():
                log.info("Downloading %s", target.relative_to(destination))
                self._retrieve(f"{root}/{name}", target)
        for name in directories:
            target = base / name
            self._mirror_tree(f"{root}/{name}/", target)

    def _retrieve(self, url: str, target: Path) -> None:
        """Download one file while displaying terminal progress."""
        with DownloadProgress(target.name) as progress:
            try:
                self.http.get_file(url, str(target), callback=progress)
            except Exception as exc:
                target.unlink(missing_ok=True)
                raise OSError(f"Download failed for {url}") from exc

    def _mirror_tree(
        self,
        url: str,
        destination: Path,
        *,
        reject: tuple[str, ...] = ("*index*",),
    ) -> None:
        """Mirror one indexed HTTP directory into an exact local directory.

        Rejected patterns match remote basenames. Paths returned by the server
        must remain below ``url`` before they are mapped beneath ``destination``.
        Directories are traversed incrementally so each file starts transferring
        as soon as it is discovered.
        """
        log.info("Downloading directory tree %s", url)
        root_url = urllib.parse.urlparse(url)
        root = PurePosixPath(urllib.parse.unquote(root_url.path))
        pending = [url]
        visited: set[str] = set()
        while pending:
            directory = pending.pop()
            if directory in visited:
                continue
            visited.add(directory)
            try:
                entries = self.http.ls(directory, detail=True)
            except Exception as exc:
                raise OSError(f"Could not list HTTP directory {directory}") from exc
            resolved = []
            for entry in entries:
                remote = str(entry.get("name", ""))
                parsed = urllib.parse.urlparse(remote)
                if parsed.query or parsed.fragment:
                    continue
                resolved.append((entry, remote, self._mirror_relative(root_url, root, remote)))
            directory_paths = {
                relative for entry, _, relative in resolved if entry.get("type") == "directory"
            }
            directories: list[str] = []
            for entry, remote, relative in sorted(resolved, key=lambda item: item[1]):
                if any(re.match(r"^[A-Za-z][A-Za-z0-9+.-]*:", part) for part in relative.parts):
                    continue
                if entry.get("type") == "directory":
                    local = destination.joinpath(*relative.parts)
                    if local.is_file():
                        local.unlink()
                    directories.append(remote)
                    continue
                if relative in directory_paths:
                    continue
                if not relative.parts or any(
                    fnmatch.fnmatch(relative.name, item) for item in reject
                ):
                    continue
                target = destination.joinpath(*relative.parts)
                if target.is_file():
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                log.info("Downloading %s", target)
                self._retrieve(remote, target)
            pending.extend(reversed(directories))

    @staticmethod
    def _mirror_relative(
        root_url: urllib.parse.ParseResult,
        root: PurePosixPath,
        remote: str,
    ) -> PurePosixPath:
        """Map a remote mirror entry to a safe path below its declared root."""
        remote_url = urllib.parse.urlparse(remote)
        if (remote_url.scheme, remote_url.netloc) != (root_url.scheme, root_url.netloc):
            raise ConfigError(f"Remote path escapes mirror root: {remote}")
        path = PurePosixPath(urllib.parse.unquote(remote_url.path))
        try:
            relative = path.relative_to(root)
        except ValueError as exc:
            raise ConfigError(f"Remote path escapes mirror root: {remote}") from exc
        if ".." in relative.parts:
            raise ConfigError(f"Remote path escapes mirror root: {remote}")
        return relative
