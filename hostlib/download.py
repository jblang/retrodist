"""Materialize the source media declared by a distro's ``[download]`` table.

The downloader supports direct URL/path pairs, official Slackware mirrors,
archived Debian release trees, and references to shared CD-ROM configs. It is
idempotent at the file level and uses wget to traverse HTTP directory indexes.
"""

from __future__ import annotations

import logging
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import urllib.parse

from .context import Context
from .config import RetroConfig, load_config
from . import CommandError, ConfigError
from .schemas.download import DownloadConfig

log = logging.getLogger(__name__)


def _mirror_identifier(value: str, setting: str) -> str:
    """Validate a mirror identifier before using it in URLs or local paths."""
    if value in {".", ".."} or re.fullmatch(r"[A-Za-z0-9._+-]+", value) is None:
        raise ConfigError(f"download.{setting} contains an unsafe release name: {value}")
    return value


MIRROR_SENTINEL = ".complete"


def download_file(url: str, target: Path) -> None:
    """Download one URL to an exact destination filename using wget."""
    try:
        result = subprocess.run(
            ["wget", "--no-verbose", "--show-progress", "--output-document", str(target), url],
            check=False,
        )
    except FileNotFoundError as exc:
        target.unlink(missing_ok=True)
        raise CommandError("wget is required to download media") from exc
    if result.returncode:
        target.unlink(missing_ok=True)
        raise CommandError(f"wget failed with status {result.returncode}")


def mirror_tree(url: str, destination: Path, reject: tuple[str, ...]) -> None:
    """Recursively mirror one URL directly beneath ``destination`` using wget."""
    marker = destination / MIRROR_SENTINEL
    if marker.is_file():
        log.info(
            "Skipping completed download; remove %s to retry",
            os.path.relpath(marker, Path.cwd()),
        )
        return
    path = urllib.parse.urlsplit(url).path.strip("/")
    cut_dirs = len(path.split("/")) if path else 0
    destination.mkdir(parents=True, exist_ok=True)
    log.info("Downloading directory tree %s", url)
    try:
        result = subprocess.run(
            [
                "wget",
                "--no-verbose",
                "--show-progress",
                "--recursive",
                "--no-parent",
                "--no-host-directories",
                f"--cut-dirs={cut_dirs}",
                f"--directory-prefix={destination}",
                "--continue",
                "--reject-regex=[?]",
                f"--reject={','.join(reject)}",
                url,
            ],
            check=False,
        )
    except FileNotFoundError as exc:
        raise CommandError("wget is required to download media") from exc
    if result.returncode:
        raise CommandError(f"wget failed with status {result.returncode}")
    marker.touch()


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

    def run(self) -> None:
        """Download all media sources required by the selected config.

        Raises:
            ConfigError: If the schema or a CD-ROM reference is invalid.
            CommandError: If wget is unavailable or a transfer fails.
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
            download_file(url, target)
        if mirror := download.slackware_mirror:
            self._slackware(mirror, destination)
        if mirror := download.debian_mirror:
            self._debian(mirror, destination)

    def _slackware(self, version: str, destination: Path) -> None:
        """Mirror the requested Slackware release tree."""
        version = _mirror_identifier(version, "slackware_mirror")
        target = destination / f"slackware-{version}"
        mirror_tree(
            f"http://mirrors.slackware.com/slackware/slackware-{version}/",
            target,
            ("*.md5*", "*.meta4", "*.sha*", "*mirror*", "*index*"),
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
        for source in self.config.extraction.package_paths:
            name = PurePosixPath(source).name
            if name.startswith("binary-"):
                dos_name = "msdos-" + name.removeprefix("binary-")
                if dos_name in directories:
                    directories.remove(dos_name)
            if name not in directories:
                directories.append(name)
        base.mkdir(parents=True, exist_ok=True)
        for name in files:
            target = base / name
            if not target.is_file():
                log.info("Downloading %s", target.relative_to(destination))
                download_file(f"{root}/{name}", target)
        for name in directories:
            target = base / name
            mirror_tree(f"{root}/{name}/", target, ("*index*",))
