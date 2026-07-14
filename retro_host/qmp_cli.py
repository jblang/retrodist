from __future__ import annotations

import argparse
import asyncio
import logging
from pathlib import Path
import sys
import tempfile

from .errors import RetroError
from .install.keyboard import encode
from .install.vga import decode
from .qmp import Monitor

log = logging.getLogger(__name__)


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="qmp-py")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("-s", "--socket", type=Path)
    common.add_argument("-w", "--timeout", type=float, default=1)
    commands = parser.add_subparsers(dest="command", required=True)
    dump = commands.add_parser("dump-screen", parents=[common])
    dump.add_argument("-a", "--address", type=lambda value: int(value, 0), default=0xB8000)
    dump.add_argument("-c", "--columns", type=int, default=80)
    dump.add_argument("-r", "--rows", type=int, default=25)
    dump.add_argument("-m", "--bytes", type=int, default=32768)
    dump.add_argument("-n", "--line-numbers", action="store_true")
    key = commands.add_parser("send-key", parents=[common])
    key.add_argument("key")
    text = commands.add_parser("send-text", parents=[common])
    text.add_argument("-n", "--enter", action="store_true")
    text.add_argument("text")
    commands.add_parser("send-stdin", parents=[common])
    change = commands.add_parser("change-image", parents=[common])
    change.add_argument("-d", "--device", default="floppy0")
    change.add_argument("image")
    eject = commands.add_parser("eject-disk", parents=[common])
    eject.add_argument("device", nargs="?", default="floppy0")
    return parser


def _socket(path: Path | None) -> Path:
    if path:
        return path
    local = Path("qmp.sock")
    return local if local.exists() else Path("qemu.d/qmp.sock")


async def _run(arguments: list[str] | None = None) -> None:
    args = _parser().parse_args(arguments)
    async with Monitor(_socket(args.socket), args.timeout) as monitor:
        if args.command == "dump-screen":
            directory = _socket(args.socket).resolve().parent
            with tempfile.NamedTemporaryFile(dir=directory, delete=False) as stream:
                dump = Path(stream.name)
            dump.unlink()
            try:
                await monitor.hmp(f"pmemsave {args.address:#x} {args.bytes} {dump}")
                lines = decode(dump.read_bytes(), args.columns, args.rows).splitlines()
                print("\n".join(f"{i:6}\t{line}" for i, line in enumerate(lines, 1)) if args.line_numbers else "\n".join(lines))
            finally:
                dump.unlink(missing_ok=True)
        elif args.command == "send-key":
            await monitor.send_key(args.key)
        elif args.command in {"send-text", "send-stdin"}:
            text = args.text if args.command == "send-text" else sys.stdin.read()
            keys = encode(text)
            if args.command == "send-text" and args.enter:
                keys.append("ret")
            for key in keys:
                await monitor.send_key(key)
        elif args.command == "change-image":
            await monitor.hmp(f"change {args.device} {args.image} raw")
        elif args.command == "eject-disk":
            await monitor.hmp(f"eject {args.device}")


def main(arguments: list[str] | None = None) -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    try:
        asyncio.run(_run(arguments))
    except (RetroError, OSError, RuntimeError, TimeoutError) as exc:
        log.error("%s", exc)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
