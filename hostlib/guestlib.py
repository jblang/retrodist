"""Stage guestlib and render its post-install configuration."""

from __future__ import annotations

from pathlib import Path, PurePosixPath
import re
import shutil

from .config import RetroConfig
from .context import Context
from .debian_packages import load_packages, render_installer, resolve_packages
from . import ConfigError
from .schemas.base import ConfigModel
from .schemas.postinst import PostinstConfig
from .slackware_tagfiles import prepare_tagfiles


def render_postinst_config(config: PostinstConfig) -> str:
    """Render post-install TOML values as portable shell assignments."""
    lines = ["# Generated from config.toml; do not edit."]
    for name, value in _postinst_variables(config).items():
        if re.fullmatch(r"[A-Z][A-Z0-9_]*", name) is None:
            raise ConfigError(f"Invalid generated post-install variable: {name}")
        lines.append(f"{name}={_shell_value(value)}")
    return "\n".join(lines) + "\n"


def _postinst_variables(config: PostinstConfig) -> dict[str, object]:
    """Flatten post-install sections to their guestlib shell variables."""
    variables: dict[str, object] = {"POSTINST_STAGES": " ".join(config.stages)}
    prefixes = {
        "modules": "MOD",
        "network": "NET",
        "tty": "TTY",
        "x11": "X11",
        "custom": "",
    }
    aliases = {
        ("network", "domain"): "NET_DOMAINNAME",
        ("network", "ip"): "NET_IPADDR",
        ("x11", "mouse_device"): "X11_MOUSEDEV",
    }
    for section, prefix in prefixes.items():
        table = getattr(config, section)
        items = (
            table.model_dump(exclude_none=True, exclude_unset=True).items()
            if isinstance(table, ConfigModel)
            else table.items()
        )
        for key, value in items:
            name = aliases.get((section, key))
            if name is None:
                name = f"{prefix}_{key}" if prefix else key
                name = name.upper()
            variables[name] = value
    for key in ("debug", "log", "reboot"):
        value = getattr(config, key)
        if value is not None:
            variables[f"POSTINST_{key.upper()}"] = value
    return variables


def _shell_value(value: object) -> str:
    """Quote one generated shell-assignment value without interpolation."""
    if isinstance(value, bool):
        value = "true" if value else "false"
    return "'" + str(value).replace("'", "'\\''") + "'"


class GuestlibStager:
    """Refresh guestlib, generated configuration, package scripts, and tagfiles."""

    def __init__(self, context: Context, config: RetroConfig) -> None:
        """Bind guest-runtime staging to the selected configuration."""
        self.context = context
        self.config = config
        self.directory = context.qemu_dir

    def stage(self) -> None:
        """Rebuild the staged guest runtime from source and configuration."""
        destination = self.directory / "fat" / "guestlib.d"
        shutil.rmtree(destination, ignore_errors=True)
        shutil.copytree(self.context.root / "guestlib", destination)
        if self.config.section("postinst"):
            self._stage_postinst(destination)
        prepare_tagfiles(self.context, self.directory, self.config.download_dir)

    def _stage_postinst(self, destination: Path) -> None:
        """Render and stage configured post-install behavior."""
        postinst_config = self.config.postinst
        distro = destination / "distro"
        distro.mkdir()
        (distro / "config.sh").write_text(render_postinst_config(postinst_config))
        if "packages" in postinst_config.stages:
            package_index = self.config.extraction.package_index
            if package_index is None:
                raise ConfigError("The packages post-install stage requires extract.package_index")
            index_path = self.directory / PurePosixPath(package_index).name
            if not index_path.is_file():
                raise ConfigError(f"Staged Debian package index not found: {index_path.name}")
            selected = resolve_packages(load_packages(index_path), postinst_config.packages)
            (distro / "packages.sh").write_text(
                render_installer(selected, postinst_config.packages)
            )
        if "custom" in postinst_config.stages:
            assert postinst_config.custom_script is not None
            script_name = postinst_config.custom_script
            postinst = self.context.find(script_name)
            if postinst is None:
                raise ConfigError(f"Custom post-install script not found: {script_name}")
            shutil.copy2(postinst, distro / "postinst.sh")
