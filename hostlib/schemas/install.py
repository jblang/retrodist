"""Configuration shared by installer families."""

from __future__ import annotations

from typing import Literal

from .base import ConfigModel


class InstallDiskConfig(ConfigModel):
    """Configure paths and partition defaults shared by installer drivers."""

    target_disk: str = "/dev/hda"
    swap_mb: int = 64
    swap_partition: str = "/dev/hda1"
    root_partition: str = "/dev/hda2"
    fat_partition: str = "/dev/hdb1"
    fat_mount: str = "/retro"
    fat_filesystem: str = "msdos"


class InstallLocaleConfig(ConfigModel):
    """Configure installer locale choices shared by family drivers."""

    hardware_clock: Literal["utc", "local"] = "utc"
    keymap: str = "us"
    timezone: str = "UTC"


class InstallPromptsConfig(ConfigModel):
    """Configure prompts shared by installer lifecycle variants."""

    boot_prompt: str = "boot:"
    boot_command: str = ""
    boot_sleep: float = 0
    postinst_prompt: str | None = None
