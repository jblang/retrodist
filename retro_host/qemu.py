from __future__ import annotations

import asyncio
from dataclasses import dataclass
import logging
from pathlib import Path
import shlex
import socket

from .config import QemuConfig
from .context import Context
from .errors import CommandError
from .qmp import Monitor

log = logging.getLogger(__name__)


def available_port() -> int:
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


@dataclass(slots=True)
class QemuRuntime:
    context: Context
    config: QemuConfig

    @property
    def directory(self) -> Path:
        return self.context.qemu_dir

    @property
    def qmp_socket(self) -> Path:
        return self.directory / "qmp.sock"

    def _startup_media(self) -> tuple[Path | None, Path | None]:
        floppy = self.directory / "fda.img"
        if not floppy.is_file() and self.context.command in {"boot", "install"}:
            floppy = self.directory / "boot.img"
        cdrom = self.directory / "hdc.iso"
        if not cdrom.is_file() and self.context.command in {"boot", "install"}:
            cdrom = self.directory / "install.iso"
        return (
            floppy if floppy.is_file() else None,
            cdrom if cdrom.is_file() else None,
        )

    async def ensure_disk(self) -> None:
        disk = self.directory / "hda.img"
        floppy, cdrom = self._startup_media()
        if disk.exists():
            return
        if not (floppy or cdrom):
            raise CommandError("No bootable devices")
        command = ["qemu-img", "create", "-f", self.config.disk_format]
        if self.config.disk_create_options:
            command += ["-o", self.config.disk_create_options]
        command += [str(disk), self.config.disk_size or "500M"]
        process = await asyncio.create_subprocess_exec(*command)
        if await process.wait():
            raise CommandError("Could not create hda.img")

    def _drives(self) -> list[str]:
        floppy, cdrom = self._startup_media()
        arguments: list[str] = []
        for name in ("fda", "fdb", "hda", "hdb", "hdc", "hdd"):
            index = {"fda": 0, "fdb": 1, "hda": 0, "hdb": 1, "hdc": 2, "hdd": 3}[name]
            interface = "floppy" if name.startswith("fd") else "ide"
            image = self.directory / f"{name}.img"
            iso = self.directory / f"{name}.iso"
            if name == "fda" and floppy:
                image = floppy
            if name == "hdc" and cdrom:
                image, iso = Path(), cdrom
            options: str | None = None
            if image.is_file():
                format = "raw" if interface == "floppy" else self.config.disk_format
                extra = (
                    f",{self.config.hda_options}"
                    if name == "hda" and self.config.hda_options
                    else ""
                )
                options = f"if={interface},index={index},format={format},file={image.name}{extra}"
            elif iso.is_file():
                options = f"if={interface},index={index},format=raw,media=cdrom,file={iso.name}"
            elif name == "hdb" and (self.directory / "fat").is_dir():
                options = "if=ide,index=1,format=raw,file=fat:rw:fat"
            elif (self.directory / name).is_dir():
                options = f"if={interface},index={index},format=raw,file=fat:rw:{name}"
            if options:
                arguments += ["-drive", options]
        return arguments

    def command(self) -> list[str]:
        cfg = self.config
        args = [
            cfg.system,
            "-machine",
            cfg.machine or "type=isapc",
            "-smp",
            str(cfg.smp),
            "-m",
            cfg.ram or "16M",
            "-qmp",
            "unix:qmp.sock,server=on,wait=off",
        ]
        for index in range(2):
            args += ["-serial", f"unix:ttyS{index}.sock,server=on,wait=off"]
        if cfg.serial_aux:
            args += ["-serial", cfg.serial_aux]
        args += ["-serial", "unix:ttyS3.sock,server=on,wait=off"]
        args += ["-parallel", "unix:lp0.sock,server=on,wait=off"]
        for option, value in (
            ("-display", cfg.display),
            ("-accel", cfg.acceleration),
            ("-vga", cfg.vga),
        ):
            if value:
                args += [option, value]
        if cfg.network_enabled and cfg.nic:
            forwards = cfg.forwards or [(available_port(), 22), (available_port(), 23)]
            netdev = "user,id=internet" + "".join(
                f",hostfwd=tcp:127.0.0.1:{host}-:{guest}" for host, guest in forwards
            )
            args += ["-netdev", netdev, "-device", f"{cfg.nic},netdev=internet"]
        if cfg.fdtype_a:
            args += ["-global", f"isa-fdc.fdtypeA={cfg.fdtype_a}"]
        if cfg.fdtype_b:
            args += ["-global", f"isa-fdc.fdtypeB={cfg.fdtype_b}"]
        args += self._drives()
        floppy, cdrom = self._startup_media()
        boot = cfg.boot_order or (
            "order=a"
            if self.context.command == "install" and floppy
            else "order=d" if self.context.command == "install" and cdrom else None
        )
        if boot:
            args += ["-boot", boot]
        return args + cfg.extra

    async def start(self) -> asyncio.subprocess.Process:
        self.directory.mkdir(parents=True, exist_ok=True)
        for socket_path in self.directory.glob("*.sock"):
            socket_path.unlink()
        await self.ensure_disk()
        command = self.command()
        log.info("🏁 Starting QEMU")
        log.info("⚙️  %s", shlex.join(command))
        return await asyncio.create_subprocess_exec(*command, cwd=self.directory)

    async def connect_monitor(self, process: asyncio.subprocess.Process) -> Monitor:
        monitor = Monitor(self.qmp_socket, timeout=10)
        connect = asyncio.create_task(monitor.connect())
        exited = asyncio.create_task(process.wait())
        done, _ = await asyncio.wait({connect, exited}, return_when=asyncio.FIRST_COMPLETED)
        if exited in done:
            connect.cancel()
            raise CommandError(f"QEMU exited during startup with status {process.returncode}")
        exited.cancel()
        await asyncio.gather(exited, return_exceptions=True)
        await connect
        return monitor
