"""Expose focused inspection and device-control commands for a running VM.

The utility discovers ``qmp.sock`` in ``qemu.d`` or the current directory and
uses the same monitor, keyboard encoder, and VGA decoder as installer
automation. It deliberately stays small enough for interactive troubleshooting.
"""

from __future__ import annotations

import argparse
import asyncio
from dataclasses import dataclass
import json
import logging
import math
from pathlib import Path
import sys
import tempfile

from .errors import RetroError
from .keyboard import encode
from .qmp import Monitor
from .vga import (
    AttributeFilter,
    ScreenSnapshot,
    VgaColor,
    decode_screen,
)

log = logging.getLogger(__name__)

_SCREEN_DUMP_SLOTS = ("a", "b")


@dataclass(frozen=True, slots=True)
class DumpScreenOptions:
    """Hold validated options for one VGA screen dump."""

    socket: Path
    address: int
    memory_bytes: int
    columns: int
    rows: int | None
    line_numbers: bool
    skip_blank: bool
    trim: bool
    changed: bool
    attributes: AttributeFilter

    def __post_init__(self) -> None:
        """Enforce invariants for non-argparse callers."""
        if self.address < 0:
            raise ValueError("address must not be negative")
        if self.memory_bytes <= 0 or self.memory_bytes % 2:
            raise ValueError("memory_bytes must be a positive even number")
        if self.columns <= 0:
            raise ValueError("columns must be greater than zero")
        if self.rows is not None and self.rows <= 0:
            raise ValueError("rows must be greater than zero")


@dataclass(frozen=True, slots=True)
class DumpGeometry:
    """Identify the VM generation and VGA memory view represented by a dump."""

    address: int
    memory_bytes: int
    columns: int
    rows: int | None
    socket_mtime_ns: int

    @classmethod
    def current(cls, options: DumpScreenOptions) -> DumpGeometry:
        """Build geometry for the active QMP socket and dump options."""
        return cls(
            address=options.address,
            memory_bytes=options.memory_bytes,
            columns=options.columns,
            rows=options.rows,
            socket_mtime_ns=options.socket.stat().st_mtime_ns,
        )

    @classmethod
    def from_dict(cls, value: object) -> DumpGeometry | None:
        """Restore validated geometry from persistent CLI state."""
        if not isinstance(value, dict):
            return None
        address = value.get("address")
        memory_bytes = value.get("bytes")
        columns = value.get("columns")
        rows = value.get("rows")
        socket_mtime_ns = value.get("socket_mtime_ns")
        if (
            not isinstance(address, int)
            or not isinstance(memory_bytes, int)
            or not isinstance(columns, int)
            or not (rows is None or isinstance(rows, int))
            or not isinstance(socket_mtime_ns, int)
        ):
            return None
        return cls(address, memory_bytes, columns, rows, socket_mtime_ns)

    def to_dict(self) -> dict[str, int | None]:
        """Return a JSON-compatible geometry representation."""
        return {
            "address": self.address,
            "bytes": self.memory_bytes,
            "columns": self.columns,
            "rows": self.rows,
            "socket_mtime_ns": self.socket_mtime_ns,
        }


@dataclass(frozen=True, slots=True)
class DumpState:
    """Track which alternating raw VGA dump is the current baseline."""

    active: str
    geometry: DumpGeometry

    @classmethod
    def load(cls, path: Path) -> DumpState | None:
        """Load state, returning ``None`` when it is absent or malformed."""
        try:
            value = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError):
            return None
        if not isinstance(value, dict) or value.get("active") not in _SCREEN_DUMP_SLOTS:
            return None
        geometry = DumpGeometry.from_dict(value)
        return cls(value["active"], geometry) if geometry is not None else None

    def save(self, path: Path) -> None:
        """Atomically persist the active slot and its dump geometry."""
        value: dict[str, object] = {"active": self.active, **self.geometry.to_dict()}
        temporary: Path | None = None
        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                dir=path.parent,
                prefix=f".{path.name}.",
                delete=False,
            ) as stream:
                temporary = Path(stream.name)
                json.dump(value, stream)
            temporary.replace(path)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)


def _color(value: str) -> VgaColor:
    """Parse a symbolic VGA color name for an attribute filter."""
    try:
        return VgaColor.parse(value)
    except ValueError as exc:
        choices = ", ".join(VgaColor.names())
        raise argparse.ArgumentTypeError(
            f"unknown VGA color {value!r}; choose from {choices}"
        ) from exc


def _background_color(value: str) -> VgaColor:
    """Parse a color that fits the classic VGA background field."""
    color = _color(value)
    if not color.is_background:
        raise argparse.ArgumentTypeError(
            f"{value!r} cannot be a VGA background color because bit 7 is blink"
        )
    return color


def _integer(value: str, *, base: int = 10) -> int:
    """Parse an integer for an argparse validator."""
    try:
        return int(value, base)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid integer: {value!r}") from exc


def _nonnegative_address(value: str) -> int:
    """Parse a nonnegative address with Python-style base prefixes."""
    parsed = _integer(value, base=0)
    if parsed < 0:
        raise argparse.ArgumentTypeError("address must not be negative")
    return parsed


def _positive_int(value: str) -> int:
    """Parse a positive decimal integer."""
    parsed = _integer(value)
    if parsed <= 0:
        raise argparse.ArgumentTypeError("value must be greater than zero")
    return parsed


def _positive_even_int(value: str) -> int:
    """Parse a positive even decimal integer."""
    parsed = _positive_int(value)
    if parsed % 2:
        raise argparse.ArgumentTypeError("value must be even")
    return parsed


def _positive_float(value: str) -> float:
    """Parse a positive floating-point value."""
    try:
        parsed = float(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"invalid number: {value!r}") from exc
    if not math.isfinite(parsed) or parsed <= 0:
        raise argparse.ArgumentTypeError("value must be greater than zero")
    return parsed


def _color_set(
    values: list[list[VgaColor]] | None,
) -> frozenset[VgaColor] | None:
    """Flatten repeatable color options into an optional filter set."""
    return frozenset(color for group in values for color in group) if values else None


def _color_pair_set(
    values: list[list[VgaColor]] | None,
) -> frozenset[tuple[VgaColor, VgaColor]] | None:
    """Convert repeatable foreground/background color-pair options into a filter set."""
    return (
        frozenset((foreground, background) for foreground, background in values)
        if values
        else None
    )


def _parser() -> argparse.ArgumentParser:
    """Build the qmp command and subcommand parser."""
    parser = argparse.ArgumentParser(prog="qmp")
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("-s", "--socket", type=Path)
    common.add_argument("-w", "--timeout", type=_positive_float, default=1)
    commands = parser.add_subparsers(dest="command", required=True)
    dump = commands.add_parser("dump-screen", parents=[common])
    dump.add_argument("-a", "--address", type=_nonnegative_address, default=0xB8000)
    dump.add_argument("-c", "--columns", type=_positive_int, default=80)
    dump.add_argument(
        "-r",
        "--rows",
        type=_positive_int,
        help="limit output to this many rows (default: all rows in screen memory)",
    )
    dump.add_argument("-m", "--bytes", type=_positive_even_int, default=32768)
    dump.add_argument("-n", "--line-numbers", action="store_true")
    dump.add_argument(
        "--skip-blank",
        action="store_true",
        help="omit blank rows when no attribute filter is active",
    )
    dump.add_argument(
        "--trim",
        action="store_true",
        help="strip leading and trailing whitespace from displayed rows",
    )
    dump.add_argument(
        "--changed",
        action="store_true",
        help="show only rows changed since the previous dump-screen command",
    )
    dump.add_argument(
        "-f",
        "--foreground",
        action="append",
        nargs="+",
        type=_color,
        metavar="COLOR",
        help="show only these foreground colors (may be repeated)",
    )
    dump.add_argument(
        "-b",
        "--background",
        action="append",
        nargs="+",
        type=_background_color,
        metavar="COLOR",
        help="show only these classic three-bit background colors (may be repeated)",
    )
    dump.add_argument(
        "--color-pair",
        action="append",
        nargs=2,
        type=_color,
        metavar=("FOREGROUND", "BACKGROUND"),
        help="show only these foreground/background pairs; background is three-bit",
    )
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
    """Resolve an explicit or conventional QMP socket path."""
    if path:
        return path
    local = Path("qmp.sock")
    return local if local.exists() else Path("qemu.d/qmp.sock")


def _dump_options(args: argparse.Namespace) -> DumpScreenOptions:
    """Translate parsed CLI values into validated screen-dump options."""
    try:
        return DumpScreenOptions(
            socket=_socket(args.socket).resolve(),
            address=args.address,
            memory_bytes=args.bytes,
            columns=args.columns,
            rows=args.rows,
            line_numbers=args.line_numbers,
            skip_blank=args.skip_blank,
            trim=args.trim,
            changed=args.changed,
            attributes=AttributeFilter(
                foreground=_color_set(args.foreground),
                background=_color_set(args.background),
                color_pairs=_color_pair_set(args.color_pair),
            ),
        )
    except ValueError as exc:
        raise RetroError(str(exc)) from exc


async def _run(arguments: list[str] | None = None) -> None:
    """Connect to QMP and execute the selected utility command."""
    args = _parser().parse_args(arguments)
    options = _dump_options(args) if args.command == "dump-screen" else None
    socket = options.socket if options is not None else _socket(args.socket)
    async with Monitor(socket, args.timeout) as monitor:
        if options is not None:
            await _dump_screen(monitor, options)
        elif args.command == "send-key":
            await monitor.send_key(args.key)
        elif args.command in {"send-text", "send-stdin"}:
            await _send_text(monitor, args)
        elif args.command == "change-image":
            await monitor.hmp(f"change {args.device} {args.image} raw")
        elif args.command == "eject-disk":
            await monitor.hmp(f"eject {args.device}")


def _previous_snapshot(path: Path | None, options: DumpScreenOptions) -> ScreenSnapshot | None:
    """Load a valid previous raw dump when change filtering is enabled."""
    if not options.changed or path is None:
        return None
    try:
        return ScreenSnapshot.capture(
            path.read_bytes(),
            options.columns,
            options.rows,
        )
    except (OSError, ValueError):
        return None


async def _dump_screen(monitor: Monitor, options: DumpScreenOptions) -> None:
    """Dump, decode, and print the guest's VGA text buffer."""
    directory = options.socket.parent
    state_path = directory / ".qmp-screen-state.json"
    geometry = DumpGeometry.current(options)
    state = DumpState.load(state_path)
    active = state.active if state is not None and state.geometry == geometry else None
    target = _SCREEN_DUMP_SLOTS[1] if active == _SCREEN_DUMP_SLOTS[0] else _SCREEN_DUMP_SLOTS[0]
    current_path = directory / f".qmp-screen-{target}.bin"
    previous_path = directory / f".qmp-screen-{active}.bin" if active is not None else None

    current_path.unlink(missing_ok=True)
    await monitor.hmp(f"pmemsave {options.address:#x} {options.memory_bytes} {current_path.name}")
    memory = current_path.read_bytes()
    screen = decode_screen(
        memory,
        options.columns,
        options.rows,
        attributes=options.attributes,
        skip_blank=options.skip_blank,
        trim_whitespace=options.trim,
        changed_from=_previous_snapshot(previous_path, options),
    )
    DumpState(target, geometry).save(state_path)
    output = (
        "\n".join(f"{row.number:6}\t{row.text}" for row in screen.rows)
        if options.line_numbers
        else screen.text
    )
    if screen.rows:
        print(output)


async def _send_text(monitor: Monitor, args: argparse.Namespace) -> None:
    """Encode command-line or standard-input text and send each guest key."""
    text = args.text if args.command == "send-text" else sys.stdin.read()
    keys = encode(text)
    if args.command == "send-text" and args.enter:
        keys.append("ret")
    for key in keys:
        await monitor.send_key(key)


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
