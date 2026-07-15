"""Convert downloaded media and declarative extraction rules into ``qemu.d``.

The standard path reads ISO images through ``pycdlib`` or copies from a source
directory, stages conventional boot/root/install media, prepares a writable FAT
tree, and applies small image transformations. Successful extraction also
refreshes guestlib and renders ``[postinst]`` as a portable ``config.sh``.

Exceptional configs may name a custom extraction script. Declarative settings
come exclusively from TOML; script contents provide actions, not configuration.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import fnmatch
import gzip
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess

from .context import Context
from .config import RetroConfig, reject_unknown
from .errors import CommandError, ConfigError


@dataclass(slots=True)
class Extraction:
    """Describe one standard, fully declarative media-staging plan.

    Paths refer to content within ``source`` and lists may contain glob
    patterns. Conventional links expose staged files to QEMU as ``boot.img``,
    ``root.img``, and ``install.iso``.
    """

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


def toml_extraction(config: RetroConfig) -> Extraction:
    """Build and validate a standard extraction plan from TOML.

    An empty plan is valid when a custom script owns extraction. Unknown keys
    and incorrectly typed fields are rejected before media is modified.

    Raises:
        ConfigError: If ``[extract]`` does not match the supported schema.
    """
    table = config.section("extract")
    reject_unknown(
        table,
        {
            "source",
            "boot_image",
            "root_image",
            "extra_images",
            "fat_files",
            "packages",
            "decompress",
            "truncate",
            "boot_link",
            "root_link",
            "packages_as_install",
            "custom_script",
        },
        "extract",
    )
    for key in ("source", "boot_image", "root_image", "packages", "boot_link", "root_link"):
        value = table.get(key)
        if value is not None and not isinstance(value, str):
            raise ConfigError(f"extract.{key} must be a string")
    for key in ("extra_images", "fat_files", "decompress", "truncate"):
        value = table.get(key, [])
        if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
            raise ConfigError(f"extract.{key} must be an array of strings")
    if not isinstance(table.get("packages_as_install", False), bool):
        raise ConfigError("extract.packages_as_install must be a boolean")
    return Extraction(
        source=str(table.get("source", "")),
        boot_image=table.get("boot_image"),
        root_image=table.get("root_image"),
        extra_images=list(table.get("extra_images", [])),
        fat_files=list(table.get("fat_files", [])),
        packages=table.get("packages"),
        decompress=list(table.get("decompress", [])),
        truncate=list(table.get("truncate", [])),
        boot_link=table.get("boot_link"),
        root_link=table.get("root_link"),
        packages_as_install=bool(table.get("packages_as_install", False)),
    )


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
        extract = self.config.section("extract")
        if not extract:
            raise ConfigError(f"No [extract] configuration for {self.context.name}")
        spec = toml_extraction(self.config)
        shell_script: Path | None = None
        if extract.get("custom_script"):
            shell_script = self.context.find(str(extract["custom_script"]))
            if shell_script is None:
                raise ConfigError(
                    f"Custom extraction script not found: {extract['custom_script']}"
                )
        self.directory.mkdir(parents=True, exist_ok=True)
        if shell_script:
            self._run_shell_script(shell_script)
        else:
            self._stage(spec)
        self._stage_kickstart()
        self._stage_guestlib()
        marker.touch()

    def _run_shell_script(self, script: Path) -> None:
        """Run an exceptional extraction script with the project environment."""
        environment = {
            "RETRO_D": str(self.context.root),
            "HOSTLIB_D": str(self.context.root / "hostlib-bash"),
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
        command = 'for library in "$HOSTLIB_D"/*.sh; do source "$library"; done; ' 'source "$1"'
        result = subprocess.run(
            ["bash", "-c", command, "extract-script", str(script)],
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

    def _stage(self, spec: Extraction) -> None:
        """Execute a standard declarative media-staging plan."""
        source = Path(spec.source)
        if not source.is_absolute():
            source = self.config.download_dir / source if spec.source else self.config.download_dir
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
            raise ConfigError(
                f"Archive extraction for {source.name} requires "
                "extract.custom_script in config.toml"
            )
        self._postprocess(spec)

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
        if spec.packages_as_install:
            install = self.directory / "fat/install"
            shutil.rmtree(install, ignore_errors=True)
            (self.directory / "fat/packages").rename(install)

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
        postinst_config = self.config.section("postinst")
        if postinst_config:
            self._validate_postinst(postinst_config)
            distro = destination / "distro"
            distro.mkdir()
            (distro / "config.sh").write_text(self._render_postinst_config(postinst_config))
            if "custom" in postinst_config.get("stages", []):
                script_name = postinst_config.get("custom_script")
                if not isinstance(script_name, str):
                    raise ConfigError("Custom post-install stage requires postinst.custom_script")
                postinst = self.context.find(script_name)
                if postinst is None:
                    raise ConfigError(f"Custom post-install script not found: {script_name}")
                shutil.copy2(postinst, distro / "postinst.sh")
        from .slackware import prepare_tagfiles

        prepare_tagfiles(self.context, self.directory, self.config.download_dir)

    @staticmethod
    def _validate_postinst(config: dict[str, object]) -> None:
        """Validate post-install stages and their declarative settings.

        ``modules``, ``network``, ``tty``, and ``x11`` map to reusable guestlib
        helpers. ``custom`` requires an explicit script and is the only stage
        that copies distro-specific executable logic into the guest runtime.
        """
        reject_unknown(
            config,
            {
                "stages",
                "custom_script",
                "debug",
                "log",
                "reboot",
                "modules",
                "network",
                "tty",
                "x11",
                "custom",
            },
            "postinst",
        )
        stages = config.get("stages", [])
        supported = {"modules", "network", "tty", "x11", "custom"}
        if not isinstance(stages, list) or not all(isinstance(stage, str) for stage in stages):
            raise ConfigError("postinst.stages must be an array of strings")
        unknown = set(stages) - supported
        if unknown:
            raise ConfigError(f"Unknown post-install stage(s): {', '.join(sorted(unknown))}")
        script = config.get("custom_script")
        if script is not None and not isinstance(script, str):
            raise ConfigError("postinst.custom_script must be a string")
        if "custom" in stages and script is None:
            raise ConfigError("Custom post-install stage requires postinst.custom_script")
        for key in ("debug", "reboot"):
            value = config.get(key)
            if value is not None and not isinstance(value, bool):
                raise ConfigError(f"postinst.{key} must be a boolean")
        if "log" in config and not isinstance(config["log"], str):
            raise ConfigError("postinst.log must be a string")
        for section in supported:
            table = config.get(section, {})
            if not isinstance(table, dict):
                raise ConfigError(f"postinst.{section} must be a table")
            if not all(
                isinstance(key, str) and isinstance(value, (str, int, bool))
                for key, value in table.items()
            ):
                raise ConfigError(f"postinst.{section} values must be scalar")

    @staticmethod
    def _render_postinst_config(config: dict[str, object]) -> str:
        """Render post-install TOML values as portable shell assignments."""
        variables: dict[str, object] = {
            "POSTINST_STAGES": " ".join(str(stage) for stage in config.get("stages", []))
        }
        prefixes = {
            "modules": "MOD",
            "network": "NET",
            "tty": "TTY",
            "x11": "X11",
            "custom": "",
        }
        aliases = {("x11", "mouse_device"): "X11_MOUSEDEV"}
        for section, prefix in prefixes.items():
            table = config.get(section, {})
            if not isinstance(table, dict):
                continue
            for key, value in table.items():
                name = aliases.get((section, key))
                if name is None:
                    name = f"{prefix}_{key}" if prefix else key
                    name = name.upper()
                variables[name] = value
        for key in ("debug", "log", "reboot"):
            if key in config:
                variables[f"POSTINST_{key.upper()}"] = config[key]
        lines = ["# Generated from config.toml; do not edit."]
        for name, value in variables.items():
            if re.fullmatch(r"[A-Z][A-Z0-9_]*", name) is None:
                raise ConfigError(f"Invalid generated post-install variable: {name}")
            if isinstance(value, bool):
                value = "true" if value else "false"
            quoted = "'" + str(value).replace("'", "'\\''") + "'"
            lines.append(f"{name}={quoted}")
        return "\n".join(lines) + "\n"
