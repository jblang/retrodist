from __future__ import annotations

import asyncio
import logging
from pathlib import Path, PurePosixPath
import urllib.parse
import urllib.request

from .context import Context
from .errors import ConfigError

log = logging.getLogger(__name__)


class Downloader:
    def __init__(self, context: Context) -> None:
        self.context = context

    async def run(self) -> None:
        if reference := self.context.find("cdrom.txt"):
            name = reference.read_text().strip()
            directory = self.context.root / "cdrom" / name
            if not directory.is_dir():
                raise ConfigError(f"CD-ROM configuration does not exist: {name}")
            cd_context = Context(self.context.root, directory, "download", self.context.temporary)
            await self._manifest(cd_context, directory / "download.d")
            self.context.qemu_dir.mkdir(parents=True, exist_ok=True)
            for image in (directory / "download.d").glob("*.iso"):
                target = self.context.qemu_dir / image.name
                target.unlink(missing_ok=True)
                target.symlink_to(image)
        await self._manifest(self.context, self.context.download_dir)

    async def _manifest(self, context: Context, destination: Path) -> None:
        manifest = context.find("download.txt")
        destination.mkdir(parents=True, exist_ok=True)
        if manifest:
            for number, raw in enumerate(manifest.read_text().splitlines(), 1):
                line = raw.strip()
                if not line or line.startswith("#"):
                    continue
                try:
                    filename, url = line.split(maxsplit=1)
                except ValueError as exc:
                    raise ConfigError(f"Invalid {manifest}:{number}") from exc
                path = PurePosixPath(filename)
                if path.is_absolute() or ".." in path.parts:
                    raise ConfigError(f"Unsafe download path in {manifest}:{number}: {filename}")
                target = destination / path
                if target.is_file():
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                log.info("Downloading %s", filename)
                await asyncio.to_thread(urllib.request.urlretrieve, url, target)
        if mirror := context.find("slackmirror.txt"):
            await self._slackware(mirror.read_text().strip(), destination)
        if mirror := context.find("debmirror.txt"):
            await self._debian(mirror.read_text().strip(), destination)
        if custom := context.find("download.py"):
            from .manifests import load

            function = getattr(load(custom), "download", None)
            if not callable(function):
                raise ConfigError(f"{custom} must define download(context, destination)")
            await asyncio.to_thread(function, context, destination)

    async def _slackware(self, version: str, destination: Path) -> None:
        target = destination / f"slackware-{version}"
        if target.is_dir():
            return
        await self._wget_tree(
            f"http://mirrors.slackware.com/slackware/slackware-{version}/",
            destination,
            cut_dirs=1,
            reject="*.md5*,*.meta4,*.sha*,*mirror*,*index*",
        )

    async def _debian(self, release: str, destination: Path) -> None:
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
                await asyncio.to_thread(urllib.request.urlretrieve, f"{root}/{name}", target)
        depth = len([part for part in urllib.parse.urlparse(root).path.split("/") if part])
        for name in directories:
            if not (base / name).is_dir():
                await self._wget_tree(f"{root}/{name}/", destination, cut_dirs=depth)

    @staticmethod
    async def _wget_tree(
        url: str, destination: Path, *, cut_dirs: int, reject: str = "*index*"
    ) -> None:
        log.info("Downloading directory tree %s", url)
        process = await asyncio.create_subprocess_exec(
            "wget",
            "--no-verbose",
            "--show-progress",
            "--recursive",
            "--no-parent",
            "--no-host-directories",
            f"--cut-dirs={cut_dirs}",
            f"--directory-prefix={destination}",
            f"--reject={reject}",
            url,
        )
        if await process.wait():
            raise OSError(f"wget failed for {url}")
