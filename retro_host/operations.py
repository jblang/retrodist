from __future__ import annotations

import asyncio
import logging
from pathlib import Path
import platform
import shlex
import shutil
import subprocess
import tarfile

from .config import load_python_config
from .context import Context
from .errors import CommandError
from .qemu import QemuRuntime

log = logging.getLogger(__name__)


async def package(context: Context) -> Path:
    runtime = QemuRuntime(context, load_python_config(context))
    context.qemu_dir.mkdir(parents=True, exist_ok=True)
    await runtime.ensure_disk()
    command = runtime.command()
    (context.qemu_dir / "retro.sh").write_text(
        "#!/bin/sh\ncd -- \"$(dirname -- \"$0\")\"\nexec " + shlex.join(command) + "\n"
    )
    (context.qemu_dir / "retro.sh").chmod(0o755)
    (context.qemu_dir / "retro.bat").write_text(
        "@echo off\r\ncd /d %~dp0\r\n" + subprocess.list2cmdline(command) + "\r\n"
    )
    name = context.name.replace("/", "-")
    archive = Path.cwd() / f"{name}.tar.gz"
    with tarfile.open(archive, "w:gz", dereference=True) as output:
        output.add(context.qemu_dir, arcname=name)
    log.info("📦 Package archive created: %s", archive)
    return archive


_PACKAGES = {
    "apt-get": ("sudo", ["apt-get", "install", "qemu-system-x86", "qemu-system-gui", "qemu-utils", "p7zip-full", "unzip", "wget", "bchunk", "mtools"]),
    "dnf": ("sudo", ["dnf", "install", "qemu-system-x86-core", "qemu-img", "qemu-ui-gtk", "7zip", "unzip", "wget", "bchunk", "mtools"]),
    "pacman": ("sudo", ["pacman", "-S", "--needed", "qemu-system-x86", "qemu-ui-gtk", "qemu-img", "p7zip", "unzip", "wget", "bchunk", "mtools"]),
}


async def install_prerequisites(*, dry_run: bool = False) -> None:
    if platform.system() == "Darwin" and shutil.which("brew"):
        command = ["brew", "install", "qemu", "p7zip", "unzip", "wget", "bchunk", "mtools"]
    else:
        manager = next((name for name in ("apt-get", "dnf", "pacman") if shutil.which(name)), None)
        if manager is None:
            raise CommandError("No supported package manager found; install QEMU, 7z, wget, bchunk, unzip, and mtools manually")
        prefix, arguments = _PACKAGES[manager]
        command = [prefix, *arguments]
    log.info("Prerequisite command: %s", shlex.join(command))
    if dry_run:
        return
    process = await asyncio.create_subprocess_exec(*command)
    if await process.wait():
        raise CommandError("Prerequisite installation failed")
