"""Compose implementation-independent configuration contracts."""

from __future__ import annotations

from typing import Annotated

from pydantic import Field, RootModel

from .debian import Debian091InstallConfig, DebianDialogInstallConfig
from .redhat import RedHatDialogInstallConfig, RedHatNewtInstallConfig, UnattendedInstallConfig
from .slackware import (
    SlackwareDialogInstallConfig,
    SlackwareTtyInstallConfig,
    SysinstallInstallConfig,
)

InstallConfig = Annotated[
    DebianDialogInstallConfig
    | SlackwareDialogInstallConfig
    | RedHatNewtInstallConfig
    | RedHatDialogInstallConfig
    | UnattendedInstallConfig
    | SysinstallInstallConfig
    | Debian091InstallConfig
    | SlackwareTtyInstallConfig,
    Field(discriminator="driver"),
]


class InstallConfigModel(RootModel[InstallConfig]):
    """Wrap the discriminated installer union for shared error translation."""
