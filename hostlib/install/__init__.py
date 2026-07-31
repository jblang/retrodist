"""Validate and dispatch installer drivers."""

from __future__ import annotations

from pathlib import Path
from typing import Callable

from ..config import RetroConfig
from .. import ConfigError
from ..qmp import Monitor
from ..session import QemuSession, run_script
from .debian_091 import run_debian_091
from .debian_dialog import run_debian_dialog
from .redhat_dialog import run_redhat_dialog
from .redhat_newt import run_redhat_newt, run_redhat_unattended
from .slackware_dialog import run_slackware_dialog
from .slackware_sysinstall import run_slackware_sysinstall
from .slackware_tty import run_slackware_tty

Driver = Callable[[QemuSession, RetroConfig], None]
DRIVERS: dict[str, Driver] = {
    "debian-091": run_debian_091,
    "debian-dialog": run_debian_dialog,
    "redhat-dialog": run_redhat_dialog,
    "redhat-newt": run_redhat_newt,
    "redhat-unattended": run_redhat_unattended,
    "slackware-dialog": run_slackware_dialog,
    "slackware-sysinstall": run_slackware_sysinstall,
    "slackware-tty": run_slackware_tty,
}


def validate_install_config(config: RetroConfig) -> Driver:
    """Validate the selected installer driver and return its entry point.

    Validation covers driver-specific option leaves and control tables before
    QEMU starts.

    Raises:
        ConfigError: If the driver configuration is invalid.
    """
    driver = config.install.driver
    try:
        return DRIVERS[driver]
    except KeyError as exc:
        raise ConfigError(f"Unknown install driver: {driver}") from exc


async def run_install(monitor: Monitor, qemu_dir: Path, config: RetroConfig) -> None:
    """Run one installer driver through the QEMU scripting lifecycle."""
    entrypoint = validate_install_config(config)
    await run_script(monitor, qemu_dir, lambda session: entrypoint(session, config))
