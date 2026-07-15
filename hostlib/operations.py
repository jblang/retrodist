"""Implement host operations that do not belong to media or VM lifecycles.

Packaging freezes the resolved QEMU command beside staged state for portable
Unix and Windows launchers.
"""

from __future__ import annotations

import logging
from pathlib import Path
import shlex
import subprocess
import tarfile

from .config import RetroConfig, load_qemu_config
from .context import Context
from .qemu import QemuRuntime

log = logging.getLogger(__name__)


def package(context: Context, config: RetroConfig) -> Path:
    """Build portable launchers and an archive from staged QEMU state.

    Symlinks are dereferenced so shared CD-ROM media remains usable outside the
    repository. The archive is created in the current working directory.

    Returns:
        Path to the generated ``.tar.gz`` archive.
    """
    runtime = QemuRuntime(context, load_qemu_config(config))
    context.qemu_dir.mkdir(parents=True, exist_ok=True)
    runtime.ensure_disk()
    command = runtime.command()
    (context.qemu_dir / "retro.sh").write_text(
        '#!/bin/sh\ncd -- "$(dirname -- "$0")"\nexec ' + shlex.join(command) + "\n"
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
