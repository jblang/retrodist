from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
import fnmatch
import gzip
import logging
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import shutil
import tempfile
from typing import Callable

from .context import Context
from .errors import CommandError, ConfigError
from .manifests import load

log = logging.getLogger(__name__)


def _shell_words(value: str, variables: dict[str, str]) -> list[str]:
    expanded = re.sub(
        r"\$(?:\{([A-Z][A-Z0-9_]*)\}|([A-Z][A-Z0-9_]*))",
        lambda match: variables.get(match.group(1) or match.group(2), match.group(0)),
        value,
    )
    return shlex.split(expanded, comments=True)


def legacy_extraction(path: Path, context: Context) -> "Extraction":
    """Read the declarative EXTRACT_* subset used by most Bash configs."""
    text = path.read_text()
    if "xorriso" in text and "/images/boot.img" in text:
        return Extraction(source="disc1.iso", boot_image="images/boot.img")
    variables = {
        "DOWNLOAD_D": str(context.download_dir),
        "EXTRACT_D": str(context.extract_dir),
        "TEMP_D": str(context.temporary),
    }
    arrays: dict[str, list[str]] = {}
    commands: list[list[str]] = []
    lines = iter(enumerate(text.splitlines(), 1))
    for number, raw in lines:
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        while "=(" in line and line.count("(") > line.count(")"):
            try:
                _, continuation = next(lines)
            except StopIteration as exc:
                raise ConfigError(f"Unterminated array in {path}:{number}") from exc
            line += " " + continuation.strip()
        if match := re.fullmatch(r"([A-Z][A-Z0-9_]*)=\((.*)\)", line):
            arrays[match.group(1)] = _shell_words(match.group(2), variables)
        elif match := re.fullmatch(r"([A-Z][A-Z0-9_]*)=(.*)", line):
            words = _shell_words(match.group(2), variables)
            variables[match.group(1)] = words[0] if words else ""
        else:
            try:
                commands.append(_shell_words(line, variables))
            except ValueError as exc:
                raise ConfigError(
                    f"Custom extraction logic at {path}:{number} requires extract.py"
                ) from exc

    allowed = {
        "extract_install_files",
        "extract_link_install_iso",
        "extract_truncate_floppy_image",
        "extract_link_boot_media",
        "gunzip",
    }

    def supported(command: list[str]) -> bool:
        return bool(command) and (
            command[0] in allowed
            or command[:3] == ["rm", "-rf", "fat/install"]
            or command[:3] == ["mv", "fat/packages", "fat/install"]
        )

    custom = next((command for command in commands if not supported(command)), None)
    if custom:
        raise ConfigError(f"Custom extraction command {custom[0]!r} in {path} requires extract.py")
    links = next(
        (
            command[1:]
            for command in commands
            if command and command[0] == "extract_link_boot_media"
        ),
        [],
    )
    install_iso = next(
        (
            command[1]
            for command in commands
            if command and command[0] == "extract_link_install_iso" and len(command) > 1
        ),
        None,
    )
    source = variables.get("EXTRACT_SOURCE", "")
    if install_iso and not source:
        source = install_iso
    decompress = [
        item
        for command in commands
        if command and command[0] == "gunzip"
        for item in command[1:]
        if not item.startswith("-")
    ]
    return Extraction(
        source=source,
        boot_image=variables.get("EXTRACT_BOOT_IMAGE") or None,
        root_image=variables.get("EXTRACT_ROOT_IMAGE") or None,
        extra_images=arrays.get("EXTRACT_EXTRA_IMAGES", []),
        fat_files=arrays.get("EXTRACT_FAT_FILES", []),
        packages=variables.get("EXTRACT_PACKAGES") or None,
        decompress=decompress,
        truncate=[
            command[1]
            for command in commands
            if command and command[0] == "extract_truncate_floppy_image" and len(command) > 1
        ],
        boot_link=links[0] if links else None,
        root_link=links[1] if len(links) > 1 else None,
        packages_as_install=any(
            command[:3] == ["mv", "fat/packages", "fat/install"] for command in commands
        ),
    )


@dataclass(slots=True)
class Extraction:
    source: str = ""
    boot_image: str | None = None
    root_image: str | None = None
    extra_images: list[str] = field(default_factory=list)
    fat_files: list[str] = field(default_factory=list)
    packages: str | None = None
    decompress: list[str] = field(default_factory=list)
    truncate: list[str] = field(default_factory=list)
    boot_link: str | None = None
    root_link: str | None = None
    packages_as_install: bool = False
    after: Callable[["MediaStager"], None] | None = None


class Iso:
    """Case-tolerant access through an ISO's richest available namespace."""

    def __init__(self, path: Path) -> None:
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
            for name in directories:
                self.paths[self._key(f"{base.rstrip('/')}/{name}")] = (
                    f"{base.rstrip('/')}/{name}",
                    True,
                )
            for name in files:
                self.paths[self._key(f"{base.rstrip('/')}/{name}")] = (
                    f"{base.rstrip('/')}/{name}",
                    False,
                )

    @staticmethod
    def _key(path: str) -> str:
        return "/" + "/".join(
            part.split(";", 1)[0].lower() for part in PurePosixPath(path).parts if part != "/"
        )

    def close(self) -> None:
        self.image.close()

    def extract_file(self, source: str, destination: Path) -> None:
        try:
            actual, directory = self.paths[self._key(source)]
        except KeyError as exc:
            raise ConfigError(f"ISO path not found: {source}") from exc
        if directory:
            raise ConfigError(f"Expected ISO file, found directory: {source}")
        destination.parent.mkdir(parents=True, exist_ok=True)
        self.image.get_file_from_iso(local_path=str(destination), **{self.argument: actual})

    def extract_files(self, source: str, destination: Path) -> None:
        matches = [
            actual
            for key, (actual, directory) in self.paths.items()
            if not directory and fnmatch.fnmatch(key, self._key(source))
        ]
        if not matches:
            raise ConfigError(f"ISO path not found: {source}")
        wildcard = any(character in source for character in "*?[")
        for actual in matches:
            name = PurePosixPath(actual if wildcard else source).name.split(";", 1)[0]
            self.extract_file(actual, destination / name)

    def extract_tree(self, source: str, destination: Path) -> None:
        prefix = self._key(source).rstrip("/")
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


class MediaStager:
    def __init__(self, context: Context) -> None:
        self.context = context
        self.directory = context.extract_dir

    async def extract(self) -> None:
        marker = self.directory / ".extracted"
        if marker.exists():
            return
        manifest = self.context.find("extract.py")
        legacy = self.context.find("extract.sh") if manifest is None else None
        shell_manifest: Path | None = None
        if manifest:
            spec = getattr(load(manifest), "extraction", None)
        elif legacy:
            try:
                spec = legacy_extraction(legacy, self.context)
            except ConfigError as exc:
                log.info("Using Bash for custom extraction manifest %s: %s", legacy, exc)
                spec = None
                shell_manifest = legacy
        else:
            raise ConfigError(
                f"No extract.py or compatible extract.sh configured for {self.context.name}"
            )
        if shell_manifest is None and not isinstance(spec, Extraction):
            raise ConfigError(f"{manifest or legacy} must define an Extraction named 'extraction'")
        self.directory.mkdir(parents=True, exist_ok=True)
        if shell_manifest:
            await self._run_shell_manifest(shell_manifest)
        else:
            assert isinstance(spec, Extraction)
            await self._stage(spec)
        await self._stage_kickstart()
        self._stage_guestlib()
        marker.touch()

    async def _run_shell_manifest(self, manifest: Path) -> None:
        environment = {
            "RETRO_D": str(self.context.root),
            "HOSTLIB_D": str(self.context.root / "hostlib"),
            "GUESTLIB_D": str(self.context.root / "guestlib"),
            "TEMP_D": str(self.context.temporary),
            "DISTRO_D": str(self.context.config),
            "QEMU_D": str(self.context.qemu_dir),
            "EXTRACT_D": str(self.context.extract_dir),
            "DOWNLOAD_D": str(self.context.download_dir),
            "TAGFILE_D": str(self.context.tagfile_dir),
            "CONFNAME": self.context.name,
            "COMMAND": self.context.command,
        }
        command = 'for library in "$HOSTLIB_D"/*.sh; do source "$library"; done; ' 'source "$1"'
        process = await asyncio.create_subprocess_exec(
            "bash",
            "-c",
            command,
            "extract-manifest",
            str(manifest),
            cwd=self.directory,
            env={**os.environ, **environment},
        )
        if await process.wait():
            raise CommandError(f"Custom extraction failed: {manifest}")

    async def _stage_kickstart(self) -> None:
        source = self.context.find("ks.cfg")
        boot = self.directory / "boot.img"
        if source is None or not boot.exists():
            return
        stripped = self.context.temporary / "ks.cfg"
        stripped.write_text(
            "\n".join(
                line
                for line in source.read_text().splitlines()
                if line.strip() and not line.lstrip().startswith("#")
            )
            + "\n"
        )
        process = await asyncio.create_subprocess_exec(
            "mcopy", "-o", "-i", str(boot), str(stripped), "::ks.cfg"
        )
        if await process.wait():
            raise CommandError(f"Could not stage {source} in {boot}")

    async def _stage(self, spec: Extraction) -> None:
        source = Path(spec.source)
        if not source.is_absolute():
            source = (
                self.context.download_dir / source if spec.source else self.context.download_dir
            )
        images = [item for item in [spec.boot_image, spec.root_image, *spec.extra_images] if item]
        if source.suffix.lower() == ".iso":
            self._link(source, self.directory / "install.iso")
            image = Iso(source)
            try:
                for item in images:
                    image.extract_files(item, self.directory)
                for item in spec.fat_files:
                    image.extract_files(item, self.directory / "fat")
                if spec.packages:
                    image.extract_tree(spec.packages, self.directory / "fat" / "packages")
            finally:
                image.close()
        elif source.is_dir():
            for item in images:
                self._copy_matches(source, item, self.directory)
            for item in spec.fat_files:
                self._copy_matches(source, item, self.directory / "fat")
            if spec.packages:
                shutil.copytree(
                    source / spec.packages,
                    self.directory / "fat" / "packages",
                    dirs_exist_ok=True,
                )
        else:
            await self._extract_with_7z(source, spec)
        self._postprocess(spec)
        if spec.after:
            spec.after(self)

    async def _extract_with_7z(self, source: Path, spec: Extraction) -> None:
        images = [item for item in [spec.boot_image, spec.root_image, *spec.extra_images] if item]
        if images:
            await self._seven_zip(source, "e", *images)
        if spec.fat_files:
            (self.directory / "fat").mkdir(exist_ok=True)
            await self._seven_zip(source, "e", "-ofat", *spec.fat_files)
        if spec.packages:
            packages = spec.packages.removeprefix("./")
            target = self.directory / "fat/packages"
            shutil.rmtree(target, ignore_errors=True)
            target.mkdir(parents=True)
            if packages == ".":
                await self._seven_zip(source, "x", "-ofat/packages")
            else:
                await self._seven_zip(source, "x", "-ofat", f"{packages}/*")
                staged = self.directory / "fat" / packages
                if not staged.is_dir():
                    raise CommandError(f"7z did not extract package tree {packages}")
                shutil.rmtree(target)
                staged.rename(target)
                top = self.directory / "fat" / PurePosixPath(packages).parts[0]
                if top != target:
                    shutil.rmtree(top, ignore_errors=True)

    async def _seven_zip(self, source: Path, mode: str, *arguments: str) -> None:
        if source.name.lower().endswith((".tar.gz", ".tgz")):
            with tempfile.NamedTemporaryFile(dir=self.context.temporary, suffix=".tar") as tar:
                unpack = await asyncio.create_subprocess_exec(
                    "7z", "x", "-so", str(source), stdout=tar
                )
                if await unpack.wait():
                    raise CommandError(f"Could not extract {source}")
                tar.flush()
                process = await asyncio.create_subprocess_exec(
                    "7z", mode, "-y", tar.name, *arguments, cwd=self.directory
                )
                status = await process.wait()
            if status:
                raise CommandError(f"Could not extract {source}")
        else:
            process = await asyncio.create_subprocess_exec(
                "7z", mode, "-y", str(source), *arguments, cwd=self.directory
            )
            if await process.wait():
                raise CommandError(f"Could not extract {source}")

    @staticmethod
    def _copy_matches(source: Path, pattern: str, destination: Path) -> None:
        path = Path(pattern)
        matches = (
            list(path.parent.glob(path.name)) if path.is_absolute() else list(source.glob(pattern))
        )
        if not matches:
            raise ConfigError(f"Source path not found: {pattern}")
        destination.mkdir(parents=True, exist_ok=True)
        for match in matches:
            shutil.copy2(match, destination / match.name)

    def _postprocess(self, spec: Extraction) -> None:
        for name in spec.decompress:
            for source in self.directory.glob(Path(name).name):
                target = source.with_suffix("")
                with gzip.open(source, "rb") as compressed, target.open("wb") as output:
                    shutil.copyfileobj(compressed, output)
                source.unlink()
        for name in spec.truncate:
            path = self.directory / Path(name).name
            if path.suffix != ".gz" and path.is_file():
                with path.open("r+b") as stream:
                    stream.truncate(1440 * 1024)
        boot = spec.boot_link or (Path(spec.boot_image).name if spec.boot_image else None)
        root = spec.root_link or (Path(spec.root_image).name if spec.root_image else None)
        if boot:
            self._link(boot, self.directory / "boot.img")
        if root:
            self._link(root, self.directory / "root.img")
        if spec.packages_as_install:
            install = self.directory / "fat/install"
            shutil.rmtree(install, ignore_errors=True)
            (self.directory / "fat/packages").rename(install)

    @staticmethod
    def _link(source: Path | str, destination: Path) -> None:
        source = Path(source)
        target = source if source.is_absolute() else destination.parent / source
        if target.absolute() == destination.absolute():
            return
        destination.unlink(missing_ok=True)
        destination.symlink_to(source)

    def _stage_guestlib(self) -> None:
        destination = self.directory / "fat" / "guestlib.d"
        shutil.rmtree(destination, ignore_errors=True)
        shutil.copytree(self.context.root / "guestlib", destination)
        if postinst := self.context.find("postinst.sh"):
            distro = destination / "distro"
            distro.mkdir()
            shutil.copy2(postinst, distro / "postinst.sh")
        from .slackware import prepare_tagfiles

        prepare_tagfiles(self.context, self.directory)
