"""Convert downloaded media and declarative extraction rules into ``qemu.d``.

The standard path reads ISO and tar images or copies from a source directory,
stages conventional boot/root/install media, prepares a writable FAT tree, and
applies small image transformations. Successful extraction also refreshes
guestlib and renders ``[postinst]`` as a portable ``config.sh``.

Exceptional configs may name a custom extraction script. Declarative settings
come exclusively from TOML; script contents provide actions, not configuration.
"""

from __future__ import annotations

import fnmatch
import gzip
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tarfile

from .context import Context
from .config import RetroConfig
from .errors import CommandError, ConfigError
from .schemas import (
    ArchiveExtract,
    ExtractionConfig,
    ImageExtract,
    Overlay,
    PostinstConfig,
)

Extraction = ExtractionConfig


def toml_extraction(config: RetroConfig) -> Extraction:
    """Build and validate a standard extraction plan from TOML.

    A custom script may preprocess media into ``custom_source`` before this
    plan stages it. Unknown keys and incorrectly typed fields are rejected
    before media is modified.

    Raises:
        ConfigError: If ``[extract]`` does not match the supported schema.
    """
    return config.extraction


class Iso:
    """Provide case-tolerant access through an ISO's richest namespace.

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
        """Normalize an ISO path for case-insensitive lookup."""
        return "/" + "/".join(
            part.split(";", 1)[0].lower() for part in PurePosixPath(path).parts if part != "/"
        )

    def close(self) -> None:
        """Close the ISO image and its backing stream."""
        self.image.close()

    def extract_file(self, source: str, destination: Path) -> None:
        """Extract one file from the ISO namespace.

        Args:
            source: Case-insensitive path within the ISO.
            destination: Host file to create, including its final filename.
        """
        try:
            actual, directory = self.paths[self._key(source)]
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
            if not directory and fnmatch.fnmatch(key, self._key(source))
        ]
        if not matches:
            raise ConfigError(f"ISO path not found: {source}")
        wildcard = any(character in source for character in "*?[")
        for actual in matches:
            name = PurePosixPath(actual if wildcard else source).name.split(";", 1)[0]
            self.extract_file(actual, destination / name)

    def extract_tree(self, source: str, destination: Path) -> None:
        """Extract a complete directory tree from the ISO."""
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
    """Stage install media and guest runtime files into ``qemu.d``.

    The extraction marker makes repeated runs cheap. Standard and custom
    extraction paths converge before kickstart injection and guest post-install
    setup.
    """

    def __init__(self, context: Context, config: RetroConfig) -> None:
        """Initialize staging for the selected distro configuration."""
        self.context = context
        self.config = config
        self.directory = context.extract_dir

    def extract(self) -> None:
        """Stage the selected config unless its extraction marker is current.

        Raises:
            ConfigError: If extraction or post-install configuration is invalid.
            CommandError: If a custom script or image tool fails.
        """
        marker = self.directory / ".extracted"
        if marker.exists():
            self._stage_guestlib()
            return
        if not self.config.section("extract"):
            raise ConfigError(f"No [extract] configuration for {self.context.name}")
        spec = toml_extraction(self.config)
        shell_script: Path | None = None
        if spec.custom_script:
            shell_script = self.context.find(spec.custom_script)
            if shell_script is None:
                raise ConfigError(f"Custom extraction script not found: {spec.custom_script}")
        self.directory.mkdir(parents=True, exist_ok=True)
        if shell_script:
            self._run_shell_script(shell_script)
            assert spec.custom_source is not None
            custom_source = self._safe_child(self.context.temporary, Path(spec.custom_source))
            self._stage(spec, custom_source)
        else:
            self._stage(spec)
        self._stage_kickstart()
        self._stage_guestlib()
        marker.touch()

    def _run_shell_script(self, script: Path) -> None:
        """Run an exceptional extraction script with the project environment."""
        environment = {
            "RETRO_D": str(self.context.root),
            "GUESTLIB_D": str(self.context.root / "guestlib"),
            "TEMP_D": str(self.context.temporary),
            "DISTRO_D": str(self.context.config),
            "QEMU_D": str(self.context.qemu_dir),
            "EXTRACT_D": str(self.context.extract_dir),
            "DOWNLOAD_D": str(self.config.download_dir),
            "TAGFILE_D": str(self.context.tagfile_dir),
            "CONFNAME": self.context.name,
            "COMMAND": self.context.command,
        }
        result = subprocess.run(
            ["bash", str(script)],
            cwd=self.directory,
            env={**os.environ, **environment},
            check=False,
        )
        if result.returncode:
            raise CommandError(f"Custom extraction failed: {script}")

    def _stage_kickstart(self) -> None:
        """Inject a configured kickstart file into the staged boot image."""
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
        result = subprocess.run(
            ["mcopy", "-o", "-i", str(boot), str(stripped), "::ks.cfg"],
            check=False,
        )
        if result.returncode:
            raise CommandError(f"Could not stage {source} in {boot}")

    def _stage(self, spec: Extraction, source: Path | None = None) -> None:
        """Execute a standard declarative media-staging plan."""
        if source is None:
            source = Path(spec.source)
            if not source.is_absolute():
                source = (
                    self.config.download_dir / source if spec.source else self.config.download_dir
                )
        images = [item for item in [spec.boot_image, spec.root_image, *spec.extra_images] if item]
        if source.suffix.lower() == ".iso":
            link_source: Path | str = source
            if source.resolve().is_relative_to(self.context.temporary.resolve()):
                staged_source = self.directory / source.name
                shutil.move(source, staged_source)
                source = staged_source
                link_source = source.name
            self._link(link_source, self.directory / "install.iso")
            image = Iso(source)
            try:
                for item in images:
                    image.extract_files(item, self.directory)
                for item in spec.fat_files:
                    image.extract_files(item, self.directory / "fat")
                if spec.package_source:
                    image.extract_tree(spec.package_source, self._package_destination(spec))
            finally:
                image.close()
        elif source.is_dir():
            for item in images:
                self._copy_matches(source, item, self.directory)
            for item in spec.fat_files:
                self._copy_matches(source, item, self.directory / "fat")
            if spec.package_source:
                shutil.copytree(
                    self._safe_child(source, Path(spec.package_source)),
                    self._package_destination(spec),
                    dirs_exist_ok=True,
                )
        elif tarfile.is_tarfile(source):
            self._stage_tar(source, spec, images)
        else:
            raise ConfigError(f"Unsupported extraction source: {source.name}")
        self._postprocess(spec)

    def _stage_tar(self, source: Path, spec: Extraction, images: list[str]) -> None:
        """Stage selected files and a package tree from a tar archive."""
        with tarfile.open(source) as archive:
            members = [member for member in archive.getmembers() if member.isfile()]
            for pattern in images:
                self._extract_tar_matches(archive, members, pattern, self.directory, flatten=True)
            for pattern in spec.fat_files:
                self._extract_tar_matches(
                    archive, members, pattern, self.directory / "fat", flatten=True
                )
            if spec.package_source:
                prefix = spec.package_source.strip("/")
                selected = [
                    member for member in members if member.name.strip("/").startswith(f"{prefix}/")
                ]
                if not selected:
                    raise ConfigError(f"Archive path not found: {spec.package_source}")
                destination = self._package_destination(spec)
                for member in selected:
                    relative = Path(member.name.strip("/")).parts[len(Path(prefix).parts) :]
                    target = self._safe_child(destination, Path(*relative))
                    target.parent.mkdir(parents=True, exist_ok=True)
                    with archive.extractfile(member) as source_file, target.open("wb") as output:
                        assert source_file is not None
                        shutil.copyfileobj(source_file, output)

    @staticmethod
    def _extract_tar_matches(
        archive: tarfile.TarFile,
        members: list[tarfile.TarInfo],
        pattern: str,
        destination: Path,
        *,
        flatten: bool,
    ) -> None:
        """Extract matching regular tar members without trusting archive paths."""
        matches = [member for member in members if fnmatch.fnmatch(member.name, pattern)]
        if not matches:
            raise ConfigError(f"Archive path not found: {pattern}")
        for member in matches:
            relative = Path(member.name).name if flatten else member.name
            target = MediaStager._safe_child(destination, Path(relative))
            target.parent.mkdir(parents=True, exist_ok=True)
            with archive.extractfile(member) as source_file, target.open("wb") as output:
                assert source_file is not None
                shutil.copyfileobj(source_file, output)

    @staticmethod
    def _safe_child(directory: Path, relative: Path) -> Path:
        """Resolve a child path and reject absolute or traversal paths."""
        target = (directory / relative).resolve()
        if not target.is_relative_to(directory.resolve()):
            raise ConfigError(f"Archive path escapes destination: {relative}")
        return target

    def _package_destination(self, spec: Extraction) -> Path:
        """Resolve the configured package destination beneath the FAT tree."""
        return self._safe_child(self.directory / "fat", Path(spec.package_dest))

    @staticmethod
    def _copy_matches(source: Path, pattern: str, destination: Path) -> None:
        """Copy files matching a source path or glob into a destination."""
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
        """Decompress and normalize staged floppy images."""
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
        self._apply_overlays(spec.overlays)
        for action in spec.image_extracts:
            self._extract_image_files(action)
        for action in spec.archive_extracts:
            self._extract_archive_files(action)

    def _apply_overlays(self, overlays: list[Overlay]) -> None:
        """Copy declarative downloaded-file replacements into staged media."""
        for overlay in overlays:
            source = Path(overlay.source)
            if not source.is_absolute():
                source = self.config.download_dir / source
            destination = self._staged_path(overlay.destination)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

    def _extract_image_files(self, action: ImageExtract) -> None:
        """Extract selected files from a staged disk image with 7-Zip."""
        image = self._staged_path(action.image)
        destination = self._staged_path(action.destination)
        shutil.rmtree(destination, ignore_errors=True)
        destination.mkdir(parents=True)
        result = subprocess.run(
            ["7z", "x", "-y", "-aoa", f"-o{destination}", str(image), *action.members],
            check=False,
            stdout=subprocess.DEVNULL,
        )
        if result.returncode:
            raise CommandError(f"Could not extract files from {image}")
        if action.lowercase:
            for path in destination.iterdir():
                lowered = path.with_name(path.name.lower())
                if lowered != path:
                    path.rename(lowered)

    def _extract_archive_files(self, action: ArchiveExtract) -> None:
        """Extract selected members from a staged tar archive in Python."""
        archive_path = self._staged_path(action.archive)
        destination = self._staged_path(action.destination)
        with tarfile.open(archive_path) as archive:
            members = [member for member in archive.getmembers() if member.isfile()]
            for pattern in action.members:
                self._extract_tar_matches(
                    archive,
                    members,
                    pattern,
                    destination,
                    flatten=action.flatten,
                )

    def _staged_path(self, value: str) -> Path:
        """Resolve and validate a path beneath the extraction directory."""
        path = (self.directory / value).resolve()
        if not path.is_relative_to(self.directory.resolve()):
            raise ConfigError(f"Extraction path escapes qemu.d: {value}")
        return path

    @staticmethod
    def _link(source: Path | str, destination: Path) -> None:
        """Create a conventional staged-media link when its source exists."""
        source = Path(source)
        target = source if source.is_absolute() else destination.parent / source
        if target.absolute() == destination.absolute():
            return
        destination.unlink(missing_ok=True)
        destination.symlink_to(source)

    def _stage_guestlib(self) -> None:
        """Refresh guestlib and render distro post-install configuration.

        Declarative values become ``distro/config.sh``. A distro-specific
        ``postinst.sh`` is copied only when the ordered stages explicitly
        request custom behavior.
        """
        destination = self.directory / "fat" / "guestlib.d"
        shutil.rmtree(destination, ignore_errors=True)
        shutil.copytree(self.context.root / "guestlib", destination)
        if self.config.section("postinst"):
            postinst_config = self.config.postinst
            distro = destination / "distro"
            distro.mkdir()
            (distro / "config.sh").write_text(self._render_postinst_config(postinst_config))
            if "custom" in postinst_config.stages:
                assert postinst_config.custom_script is not None
                script_name = postinst_config.custom_script
                postinst = self.context.find(script_name)
                if postinst is None:
                    raise ConfigError(f"Custom post-install script not found: {script_name}")
                shutil.copy2(postinst, distro / "postinst.sh")
        from .slackware import prepare_tagfiles

        prepare_tagfiles(self.context, self.directory, self.config.download_dir)

    @staticmethod
    def _render_postinst_config(config: PostinstConfig) -> str:
        """Render post-install TOML values as portable shell assignments."""
        variables: dict[str, object] = {"POSTINST_STAGES": " ".join(config.stages)}
        prefixes = {
            "modules": "MOD",
            "network": "NET",
            "tty": "TTY",
            "x11": "X11",
            "custom": "",
        }
        aliases = {("x11", "mouse_device"): "X11_MOUSEDEV"}
        for section, prefix in prefixes.items():
            table = getattr(config, section)
            for key, value in table.items():
                name = aliases.get((section, key))
                if name is None:
                    name = f"{prefix}_{key}" if prefix else key
                    name = name.upper()
                variables[name] = value
        for key in ("debug", "log", "reboot"):
            value = getattr(config, key)
            if value is not None:
                variables[f"POSTINST_{key.upper()}"] = value
        lines = ["# Generated from config.toml; do not edit."]
        for name, value in variables.items():
            if re.fullmatch(r"[A-Z][A-Z0-9_]*", name) is None:
                raise ConfigError(f"Invalid generated post-install variable: {name}")
            if isinstance(value, bool):
                value = "true" if value else "false"
            quoted = "'" + str(value).replace("'", "'\\''") + "'"
            lines.append(f"{name}={quoted}")
        return "\n".join(lines) + "\n"
