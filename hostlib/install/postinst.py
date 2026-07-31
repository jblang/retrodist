"""Shared guest commands and post-installation helpers for installer drivers."""

from __future__ import annotations

import shlex

from ..config import RetroConfig
from ..session import Match, QemuSession


def fat_mount_command(mount: str, partition: str, filesystem: str) -> str:
    """Return a quoted command that mounts the staged FAT exchange partition."""
    quoted_mount = shlex.quote(mount)
    return (
        f"mkdir -p {quoted_mount} && "
        f"mount -t {shlex.quote(filesystem)} {shlex.quote(partition)} {quoted_mount}"
    )


def postinst_command(config: RetroConfig) -> str:
    """Return the configured guest command that runs post-installation."""
    disk = config.install.disk
    mount = disk.fat_mount
    filesystem = config.postinst.fat_filesystem or disk.fat_filesystem
    return (
        f"if [ ! -d {shlex.quote(mount)}/guestlib.d ]; then "
        f"{fat_mount_command(mount, disk.fat_partition, filesystem)}; fi; "
        f"{shlex.quote(mount)}/guestlib.d/postinst.sh"
    )


def run_postinst(
    session: QemuSession,
    config: RetroConfig,
    password: str | None = None,
    *,
    login: str = "login:",
    shell: str = "#",
) -> None:
    """Log in as root and launch the staged post-installation runner."""
    session.vga_wait(login, match=Match.LINE)
    session.kb_type("root\n")
    if password is not None:
        session.vga_wait("Password:")
        session.kb_type(f"{password}\n")
    session.vga_wait(shell, match=Match.LINE)
    session.kb_type(f"{postinst_command(config)}\n")
