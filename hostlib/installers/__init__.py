"""Validate and dispatch typed Python installer drivers."""

from __future__ import annotations

from typing import Callable

from ..config import RetroConfig
from ..errors import ConfigError
from ..session import InstallSession
from .debian_091 import run_debian_091
from .debian_dialog import run_debian_dialog
from .redhat_dialog import run_redhat_dialog
from .redhat_newt import run_redhat_newt, run_redhat_unattended
from .slackware_dialog import run_slackware_dialog
from .slackware_sysinstall import run_slackware_sysinstall
from .slackware_tty import run_slackware_tty

Driver = Callable[[InstallSession], None]


def validate_install_config(config: RetroConfig) -> Driver:
    """Validate the selected installer driver and return its entry point.

    Validation covers driver-specific option leaves and control tables before
    QEMU starts.

    Raises:
        ConfigError: If the driver configuration is invalid.
    """
    driver = config.install.driver
    try:
        entrypoint = DRIVERS[driver]
    except KeyError as exc:
        raise ConfigError(f"Unknown install driver: {driver}") from exc
    return entrypoint


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
