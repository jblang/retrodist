"""Orchestrate the synchronous ``retro`` workflow and live QEMU lifecycle.

Commands share one ``Context`` and resolved ``RetroConfig``. Download, staging,
and packaging remain synchronous; an event loop is created only while QEMU and
installer transports are live.
"""

from __future__ import annotations

import argparse
import asyncio
import logging
from pathlib import Path
import shlex
import shutil
import subprocess
import tarfile

from . import RetroError
from .config import QemuConfig, RetroConfig, load_config
from .context import Context
from .download import Downloader
from .install import run_install, validate_install_config
from .media import MediaStager
from .qemu import QemuRuntime
from .slackware_tagfiles import generate_default_tag

log = logging.getLogger(__name__)
COMMANDS = (
    "help",
    "boot",
    "install",
    "extract",
    "download",
    "tagfile",
    "package",
    "reset",
)


def parser() -> argparse.ArgumentParser:
    """Build the argument parser for the retro command."""
    result = argparse.ArgumentParser(
        prog="retro",
        description="Python host runtime for Retro Distro Playground",
    )
    result.add_argument("command", choices=COMMANDS, nargs="?", default="help")
    result.add_argument("config", nargs="?")
    result.add_argument("--debug", action="store_true")
    return result


class Application:
    """Coordinate one top-level ``retro`` command.

    Dependency ordering is centralized here: operations that need staged media
    automatically download and extract first, while install validation occurs
    before expensive VM startup.
    """

    def __init__(self, context: Context, config: RetroConfig) -> None:
        """Initialize the application with its selected context and configuration."""
        self.context = context
        self.config = config

    def run(self) -> None:
        """Dispatch the selected top-level command."""
        match self.context.command:
            case "help":
                parser().print_help()
            case "boot" | "install":
                self.boot(install=self.context.command == "install")
            case "download":
                Downloader(self.context, self.config).run()
            case "extract":
                self._prepare_media()
            case "reset":
                self.reset()
            case "tagfile":
                self._prepare_media()
                generate_default_tag(self.context, self.context.qemu_dir)
            case "package":
                self._prepare_media()
                self.package()

    def _prepare_media(self) -> None:
        """Download and stage all media required by later operations."""
        Downloader(self.context, self.config).run()
        MediaStager(self.context, self.config).extract()

    def boot(self, *, install: bool) -> None:
        """Stage media and start QEMU for a boot or automated install."""
        qemu_config = self.config.qemu
        if install:
            validate_install_config(self.config)
        self._prepare_media()
        asyncio.run(self._run_vm(qemu_config, install=install))

    async def _run_vm(self, qemu_config: QemuConfig, *, install: bool) -> None:
        """Own the live QEMU process and optional installer session.

        Installer failures are logged while the VM remains available for
        inspection. QMP is released for the standalone utility, and the command
        waits until the user closes QEMU. Cancellation still terminates QEMU.
        """
        runtime = QemuRuntime(self.context, qemu_config)
        process = await runtime.start()
        monitor = await runtime.connect_monitor(process)
        try:
            if install:
                try:
                    await run_install(
                        monitor,
                        self.context.qemu_dir,
                        self.config,
                    )
                except Exception:
                    log.exception(
                        "Installer automation failed; QEMU remains running for inspection"
                    )
                    await monitor.close()
                    monitor = None
                else:
                    log.info("🎉 Installation complete!")
            else:
                # QEMU accepts one QMP client on its Unix socket. A plain boot
                # has no automation to run, so release the monitor for the
                # standalone qmp command while the VM remains open.
                await monitor.close()
                monitor = None
            status = await process.wait()
            if status:
                raise RetroError(f"QEMU exited with status {status}")
        finally:
            if monitor is not None:
                await monitor.close()
            if process.returncode is None:
                process.terminate()
                await process.wait()

    def reset(self) -> None:
        """Confirm and remove generated QEMU state."""
        answer = input(f"Really remove QEMU state for {self.context.name}? ")
        if answer.lower().startswith("y"):
            shutil.rmtree(self.context.qemu_dir, ignore_errors=True)

    def package(self) -> Path:
        """Build portable launchers and an archive from staged QEMU state.

        Symlinks are dereferenced so shared CD-ROM media remains usable outside
        the repository. The archive is created in the current working directory.
        """
        runtime = QemuRuntime(self.context, self.config.qemu)
        self.context.qemu_dir.mkdir(parents=True, exist_ok=True)
        runtime.ensure_disk()
        command = runtime.command()
        (self.context.qemu_dir / "retro.sh").write_text(
            '#!/bin/sh\ncd -- "$(dirname -- "$0")"\nexec ' + shlex.join(command) + "\n"
        )
        (self.context.qemu_dir / "retro.sh").chmod(0o755)
        (self.context.qemu_dir / "retro.bat").write_text(
            "@echo off\r\ncd /d %~dp0\r\n" + subprocess.list2cmdline(command) + "\r\n"
        )
        name = self.context.name.replace("/", "-")
        archive = Path.cwd() / f"{name}.tar.gz"
        with tarfile.open(archive, "w:gz", dereference=True) as output:
            output.add(self.context.qemu_dir, arcname=name)
        log.info("📦 Package archive created: %s", archive)
        return archive


def run_main(arguments: list[str] | None = None) -> int:
    """Parse arguments and run one ``retro`` command, returning its status.

    The per-command temporary directory is removed regardless of success. User-
    facing exception translation remains in ``main``.
    """
    args = parser().parse_args(arguments)
    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(levelname)s: %(message)s",
    )
    root = Path(__file__).resolve().parent.parent
    context = Context.create(root, args.command, args.config)
    try:
        log.info("🐧 Starting retro %s for %s", context.command, context.name)
        Application(context, load_config(context)).run()
        return 0
    finally:
        shutil.rmtree(context.temporary, ignore_errors=True)


def main(arguments: list[str] | None = None) -> None:
    """Run the command-line entry point and translate host errors to exit status."""
    try:
        raise SystemExit(run_main(arguments))
    except (RetroError, OSError, TimeoutError) as exc:
        log.error("%s", exc)
        raise SystemExit(1) from exc
