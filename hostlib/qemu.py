"""Translate resolved host configuration and staged media into a QEMU process.

This module owns disk creation, conventional media attachment, loopback port
forward allocation, Unix-socket character devices, startup reporting, and the
race between QMP readiness and premature emulator exit.
"""

from __future__ import annotations

import asyncio
from dataclasses import dataclass, field
import logging
from pathlib import Path
import shlex
import socket
import subprocess

from .config import QemuConfig
from .context import Context
from .errors import CommandError
from .qmp import Monitor

log = logging.getLogger(__name__)


def available_port(base: int) -> int:
    """Return the first bindable loopback TCP port in a 100-port range.

    Raises:
        CommandError: If no port from ``base`` through ``base + 99`` is free.
    """
    for port in range(base, base + 100):
        with socket.socket() as listener:
            try:
                listener.bind(("127.0.0.1", port))
            except OSError:
                continue
        return port
    raise CommandError(f"No available port from {base} through {base + 99}")


@dataclass(slots=True)
class QemuRuntime:
    """Build and manage one QEMU process for a selected config.

    Staged filenames are the boundary between extraction and emulation. The
    runtime discovers conventional floppy, IDE, CD-ROM, and FAT-directory names
    in ``qemu.d`` and combines them with a fully resolved ``QemuConfig``.
    """

    context: Context
    config: QemuConfig
    _assigned_forwards: list[tuple[int, int]] | None = field(default=None, init=False)

    @property
    def directory(self) -> Path:
        """Return the generated QEMU working directory."""
        return self.context.qemu_dir

    @property
    def qmp_socket(self) -> Path:
        """Return the QMP Unix-socket path."""
        return self.directory / "qmp.sock"

    def _startup_media(self) -> tuple[Path | None, Path | None]:
        """Select staged floppy and CD-ROM startup media."""
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

    def ensure_disk(self) -> None:
        """Create the primary hard disk when required and absent.

        Raises:
            CommandError: If there is no startup media or ``qemu-img`` fails.
        """
        disk = self.directory / "hda.img"
        floppy, cdrom = self._startup_media()
        if disk.exists():
            return
        if not (floppy or cdrom):
            raise CommandError("No bootable devices")
        command = ["qemu-img", "create", "-f", self.config.disk.format]
        if self.config.disk.create_options:
            command += ["-o", self.config.disk.create_options]
        command += [str(disk), self.config.disk.size or "500M"]
        result = subprocess.run(command, check=False)
        if result.returncode:
            raise CommandError("Could not create hda.img")

    def _drives(self) -> list[str]:
        """Build QEMU drive option strings from staged conventional media."""
        floppy, cdrom = self._startup_media()
        return [
            options
            for name in ("fda", "fdb", "hda", "hdb", "hdc", "hdd")
            if (options := self._drive_options(name, floppy, cdrom))
        ]

    def _drive_options(self, name: str, floppy: Path | None, cdrom: Path | None) -> str | None:
        """Build options for one conventional floppy or IDE device.

        Command-specific startup media overrides conventional filenames. Disk
        images take precedence over ISOs, followed by the staged FAT directory
        conventions used for writable guest exchange media.
        """
        indices = {"fda": 0, "fdb": 1, "hda": 0, "hdb": 1, "hdc": 2, "hdd": 3}
        interface = "floppy" if name.startswith("fd") else "ide"
        image: Path | None = floppy if name == "fda" and floppy else self.directory / f"{name}.img"
        iso = cdrom if name == "hdc" and cdrom else self.directory / f"{name}.iso"
        if name == "hdc" and cdrom:
            image = None
        if image is not None and image.is_file():
            return self._image_drive_options(name, image, interface, indices[name])
        if iso.is_file():
            return f"if={interface},index={indices[name]},format=raw,media=cdrom,file={iso.name}"
        if name == "hdb" and (self.directory / "fat").is_dir():
            return "if=ide,index=1,format=raw,file=fat:rw:fat"
        if (self.directory / name).is_dir():
            return f"if={interface},index={indices[name]},format=raw,file=fat:rw:{name}"
        return None

    def _image_drive_options(self, name: str, image: Path, interface: str, index: int) -> str:
        """Build options for a staged disk-image drive."""
        image_format = "raw" if interface == "floppy" else self.config.disk.format
        extra = (
            f",{self.config.disk.hda_options}"
            if name == "hda" and self.config.disk.hda_options
            else ""
        )
        return f"if={interface},index={index},format={image_format},file={image.name}{extra}"

    def _forwards(self) -> list[tuple[int, int]]:
        """Resolve configured or automatically assigned host port forwards."""
        if self._assigned_forwards is None:
            if self.config.network.forwards is None:
                self._assigned_forwards = [
                    (available_port(2200), 22),
                    (available_port(2300), 23),
                ]
            else:
                self._assigned_forwards = [
                    (pair[0], pair[1]) for pair in self.config.network.forwards
                ]
        return self._assigned_forwards

    def _chardevs(self) -> list[tuple[str, str]]:
        """Build serial and parallel Unix-socket endpoints.

        ``ttyS0.sock`` and ``ttyS1.sock`` expose ordinary guest serial ports,
        ``ttyS3.sock`` is reserved for installer automation, and ``lp0.sock``
        captures the first parallel port.
        """
        devices = [
            ("-serial", "unix:ttyS0.sock,server=on,wait=off"),
            ("-serial", "unix:ttyS1.sock,server=on,wait=off"),
        ]
        if self.config.serial.auxiliary:
            devices.append(("-serial", self.config.serial.auxiliary))
        devices.extend(
            [
                ("-serial", "unix:ttyS3.sock,server=on,wait=off"),
                ("-parallel", "unix:lp0.sock,server=on,wait=off"),
            ]
        )
        return devices

    def command(self) -> list[str]:
        """Build the complete QEMU argument vector.

        Port assignments are cached, so this method and startup reporting refer
        to exactly the same forwarded endpoints.
        """
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
        args += self._device_arguments()
        for drive in self._drives():
            args += ["-drive", drive]
        boot = self._boot_order()
        if boot:
            args += ["-boot", boot]
        return args + cfg.extra

    def _device_arguments(self) -> list[str]:
        """Build character, display, network, and floppy-controller arguments."""
        args = [value for pair in self._chardevs() for value in pair]
        display = self.config.display
        for option, value in (
            ("-display", display.backend),
            ("-accel", display.acceleration),
            ("-vga", display.vga),
        ):
            if value:
                args += [option, value]
        args += self._network_arguments()
        for drive, value in (
            ("A", self.config.disk.floppy_a_type),
            ("B", self.config.disk.floppy_b_type),
        ):
            if value:
                args += ["-global", f"isa-fdc.fdtype{drive}={value}"]
        return args

    def _network_arguments(self) -> list[str]:
        """Build user-network and forwarding arguments when networking is enabled."""
        network = self.config.network
        if not (network.enabled and network.device):
            return []
        netdev = "user,id=internet" + "".join(
            f",hostfwd=tcp:127.0.0.1:{host}-:{guest}" for host, guest in self._forwards()
        )
        return ["-netdev", netdev, "-device", f"{network.device},netdev=internet"]

    def _boot_order(self) -> str | None:
        """Resolve an explicit or install-media-derived QEMU boot order."""
        floppy, cdrom = self._startup_media()
        if self.config.boot_order:
            return self.config.boot_order
        if self.context.command != "install":
            return None
        return "order=a" if floppy else "order=d" if cdrom else None

    def _report_devices(self) -> None:
        """Log QMP, forwarding, disk, and character-device endpoints."""
        log.info("⚙️  QEMU endpoints:")
        log.info("    QMP:     %s", self.qmp_socket.name)
        self._report_forwards()
        self._report_drives()
        self._report_chardevs()

    def _report_forwards(self) -> None:
        """Log configured guest TCP port forwarding endpoints."""
        forwards = (
            self._forwards() if self.config.network.enabled and self.config.network.device else []
        )
        if forwards:
            log.info("📡 Guest ports:")
            ordered = sorted(
                forwards,
                key=lambda pair: (pair[1] not in {22, 23}, pair[1]),
            )
            for host, guest in ordered:
                label = "SSH" if guest == 22 else "Telnet" if guest == 23 else "TCP"
                log.info("    %-7s localhost:%s -> guest :%s", f"{label}:", host, guest)

    def _report_drives(self) -> None:
        """Log all conventional staged disk arguments."""
        log.info("💾 Guest disks:")
        drives = self._drives()
        if drives:
            for drive in drives:
                log.info("    -drive %s", drive)
        else:
            log.info("    none")

    def _report_chardevs(self) -> None:
        """Log exported serial and parallel character-device endpoints."""
        log.info("⌨️  Guest character devices:")
        exported = [
            (option, value)
            for option, value in self._chardevs()
            if value.startswith(("unix:", "pipe:"))
        ]
        for option, value in exported:
            log.info("    %s %s", option, value)

    async def start(self) -> asyncio.subprocess.Process:
        """Prepare state, report devices, and start QEMU.

        Stale sockets are removed before launch. The returned process is owned
        by the CLI, which is responsible for waiting and termination cleanup.
        """
        self.directory.mkdir(parents=True, exist_ok=True)
        for socket_path in self.directory.glob("*.sock"):
            socket_path.unlink()
        self.ensure_disk()
        command = self.command()
        self._report_devices()
        log.info("🏁 Starting QEMU")
        log.info("#️⃣  Command: %s", shlex.join(command))
        return await asyncio.create_subprocess_exec(*command, cwd=self.directory)

    async def connect_monitor(self, process: asyncio.subprocess.Process) -> Monitor:
        """Connect QMP while also watching for premature QEMU exit.

        Raises:
            CommandError: If QEMU exits before its QMP socket becomes usable.
            QmpUnavailable: If QMP does not connect within the monitor timeout.
        """
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
