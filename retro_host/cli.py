from __future__ import annotations

import argparse
import asyncio
import logging
from pathlib import Path
import shutil
import sys

from .config import load_python_config
from .context import Context
from .errors import ConfigError, RetroError
from .download import Downloader
from .install.session import run_install
from .manifests import load
from .media import MediaStager
from .operations import install_prerequisites, package
from .qemu import QemuRuntime
from .slackware import generate_default_tag

log = logging.getLogger(__name__)
COMMANDS = (
    "help",
    "boot",
    "install",
    "extract",
    "download",
    "tagfile",
    "package",
    "prereq",
    "reset",
)


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(
        prog="retro.py",
        description="Python host runtime for Retro Distro Playground",
    )
    result.add_argument("command", choices=COMMANDS, nargs="?", default="help")
    result.add_argument("config", nargs="?")
    result.add_argument("--debug", action="store_true")
    result.add_argument(
        "--dry-run",
        action="store_true",
        help="print prerequisite command without running it",
    )
    return result


class Application:
    def __init__(self, context: Context, *, dry_run: bool = False) -> None:
        self.context = context
        self.dry_run = dry_run

    async def run(self) -> None:
        match self.context.command:
            case "help":
                parser().print_help()
            case "boot" | "install":
                await self.boot(install=self.context.command == "install")
            case "download":
                await Downloader(self.context).run()
            case "extract":
                await Downloader(self.context).run()
                await MediaStager(self.context).extract()
            case "reset":
                self.reset()
            case "tagfile":
                await Downloader(self.context).run()
                await MediaStager(self.context).extract()
                generate_default_tag(self.context, self.context.qemu_dir)
            case "package":
                await Downloader(self.context).run()
                await MediaStager(self.context).extract()
                await package(self.context)
            case "prereq":
                await install_prerequisites(dry_run=self.dry_run)

    async def boot(self, *, install: bool) -> None:
        await Downloader(self.context).run()
        await MediaStager(self.context).extract()
        runtime = QemuRuntime(self.context, load_python_config(self.context))
        process = await runtime.start()
        monitor = await runtime.connect_monitor(process)
        try:
            if install:
                path = self.context.find("install.py")
                if path is None:
                    raise ConfigError(f"No install.py configured for {self.context.name}")
                entrypoint = getattr(load(path), "install", None)
                if entrypoint is None:
                    raise ConfigError(f"{path} must define install(session)")
                await run_install(monitor, self.context.qemu_dir, entrypoint)
                log.info("🎉 Install script complete!")
            status = await process.wait()
            if status:
                raise RetroError(f"QEMU exited with status {status}")
        finally:
            await monitor.close()
            if process.returncode is None:
                process.terminate()
                await process.wait()

    def reset(self) -> None:
        answer = input(f"Really remove QEMU state for {self.context.name}? ")
        if answer.lower().startswith("y"):
            shutil.rmtree(self.context.qemu_dir, ignore_errors=True)


async def async_main(arguments: list[str] | None = None) -> int:
    args = parser().parse_args(arguments)
    logging.basicConfig(
        level=logging.DEBUG if args.debug else logging.INFO,
        format="%(levelname)s: %(message)s",
    )
    root = Path(__file__).resolve().parent.parent
    context = Context.create(root, args.command, args.config)
    try:
        log.info("🐧 Starting retro.py %s for %s", context.command, context.name)
        await Application(context, dry_run=args.dry_run).run()
        return 0
    finally:
        shutil.rmtree(context.temporary, ignore_errors=True)


def main(arguments: list[str] | None = None) -> None:
    try:
        raise SystemExit(asyncio.run(async_main(arguments)))
    except (RetroError, OSError, TimeoutError) as exc:
        log.error("%s", exc)
        raise SystemExit(1) from exc
