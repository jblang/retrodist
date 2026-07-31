"""Coordinate downloaded-media staging into ``qemu.d``.

The public stager sequences source extraction, exceptional custom hooks, image
transformations, kickstart injection, and guestlib refresh. Format-specific
extraction and guestlib assembly live behind focused collaborators.
"""

from __future__ import annotations

import gzip
import os
from pathlib import Path
import shutil
import subprocess

from .config import RetroConfig
from .context import Context
from . import CommandError, ConfigError
from .guestlib import GuestlibStager
from .media_extract import MediaExtractor, link_media, safe_child
from .schemas.media import ExtractionConfig, Overlay


def _needs_staging(spec: ExtractionConfig) -> bool:
    """Return whether declarative extraction needs downloaded source media."""
    return bool(spec.source or spec.staged_files or spec.fat_files or spec.package_paths)


class MediaStager:
    """Sequence media extraction, transformation, and guestlib staging."""

    def __init__(self, context: Context, config: RetroConfig) -> None:
        """Initialize staging for the selected distro configuration."""
        self.context = context
        self.config = config
        self.directory = context.qemu_dir
        self.extractor = MediaExtractor(context, config)
        self.guestlib = GuestlibStager(context, config)

    def extract(self) -> None:
        """Stage the selected config unless its extraction marker is current."""
        marker = self.directory / ".extracted"
        if marker.exists():
            self.guestlib.stage()
            return
        if not self.config.section("extract"):
            raise ConfigError(f"No [extract] configuration for {self.context.name}")
        spec = self.config.extraction
        shell_script: Path | None = None
        if spec.custom_script:
            shell_script = self.context.find(spec.custom_script)
            if shell_script is None:
                raise ConfigError(f"Custom extraction script not found: {spec.custom_script}")
        self.directory.mkdir(parents=True, exist_ok=True)
        if _needs_staging(spec):
            self.extractor.stage(spec)
        if shell_script:
            self._run_shell_script(shell_script)
        self._postprocess(spec)
        self._stage_kickstart()
        self.guestlib.stage()
        marker.touch()

    def _run_shell_script(self, script: Path) -> None:
        """Run an exceptional extraction script from the staging directory."""
        environment = {
            "RETRO_D": str(self.context.root),
            "GUESTLIB_D": str(self.context.root / "guestlib"),
            "DISTRO_D": str(self.context.config),
            "QEMU_D": str(self.context.qemu_dir),
            "DOWNLOAD_D": str(self.config.download_dir),
            "TAGFILE_D": str(self.context.tagfile_dir),
            "CONFNAME": self.context.name,
            "COMMAND": self.context.command,
        }
        result = subprocess.run(
            ["bash", "-e", "-o", "pipefail", str(script)],
            cwd=self.directory,
            env={**os.environ, **environment},
            check=False,
        )
        if result.returncode:
            raise CommandError(f"Custom extraction failed: {script}")

    def _postprocess(self, spec: ExtractionConfig) -> None:
        """Normalize images, create conventional links, and apply overlays."""
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
            link_media(boot, self.directory / "boot.img")
        if root:
            link_media(root, self.directory / "root.img")
        self._apply_overlays(spec.overlays)

    def _apply_overlays(self, overlays: list[Overlay]) -> None:
        """Copy declarative downloaded-file replacements into staged media."""
        for overlay in overlays:
            source = Path(overlay.source)
            if not source.is_absolute():
                source = self.config.download_dir / source
            destination = safe_child(self.directory, Path(overlay.destination))
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)

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
