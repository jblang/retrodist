"""Expose focused inspection and device-control commands for a running VM."""

from __future__ import annotations

import argparse
import asyncio
import logging
import math
from pathlib import Path

from .errors import RetroError
from .keyboard import encode
from .qmp import Monitor
from .vga import ScreenObserver

log = logging.getLogger(__name__)


def _positive_float(value: str) -> float:
    """Parse a positive finite timeout."""
    try:
        parsed = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid number: {value!r}") from exc
    if not math.isfinite(parsed) or parsed <= 0:
        raise argparse.ArgumentTypeError("value must be greater than zero")
    return parsed


def _parser() -> argparse.ArgumentParser:
    """Build the qmp command and subcommand parser."""
    parser = argparse.ArgumentParser(prog="qmp")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("-s", "--socket", type=Path)
    common.add_argument("-w", "--timeout", type=_positive_float, default=1)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("dump-screen", parents=[common])
    key = commands.add_parser("send-key", parents=[common])
    key.add_argument("key")
    text = commands.add_parser("send-text", parents=[common])
    text.add_argument("-n", "--enter", action="store_true")
    text.add_argument("text")
    change = commands.add_parser("change-image", parents=[common])
    change.add_argument("-d", "--device", default="floppy0")
    change.add_argument("image")
    eject = commands.add_parser("eject-disk", parents=[common])
    eject.add_argument("device", nargs="?", default="floppy0")
    return parser


def _socket(path: Path | None) -> Path:
    """Resolve an explicit or conventional QMP socket path."""
    if path:
        return path
    local = Path("qmp.sock")
    return local if local.exists() else Path("qemu.d/qmp.sock")


async def _run(arguments: list[str] | None = None) -> None:
    """Connect to QMP and execute the selected utility command."""
    args = _parser().parse_args(arguments)
    socket = _socket(args.socket)
    async with Monitor(socket, args.timeout) as monitor:
        if args.command == "dump-screen":
            await _dump_screen(monitor, socket)
        elif args.command == "send-key":
            await monitor.send_key(args.key)
        elif args.command == "send-text":
            keys = encode(args.text)
            if args.enter:
                keys.append("ret")
            for key in keys:
                await monitor.send_key(key)
        elif args.command == "change-image":
            await monitor.hmp(f"change {args.device} {args.image} raw")
        elif args.command == "eject-disk":
            await monitor.hmp(f"eject {args.device}")


async def _dump_screen(monitor: Monitor, socket: Path) -> None:
    """Dump and print the guest's standard VGA text buffer."""
    snapshot = await ScreenObserver(monitor, socket.parent).capture()
    print(snapshot.text)


def main(arguments: list[str] | None = None) -> None:
    """Run the command-line entry point and translate host errors to exit status."""
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    try:
        asyncio.run(_run(arguments))
    except (RetroError, OSError, RuntimeError, TimeoutError) as exc:
        log.error("%s", exc)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
