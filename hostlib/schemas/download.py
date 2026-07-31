"""Typed configuration for source-media downloads."""

from __future__ import annotations

from pydantic import Field

from .base import ConfigModel


class DownloadFile(ConfigModel):
    """Validate one direct download declaration."""

    path: str
    url: str


class DownloadConfig(ConfigModel):
    """Configure direct files and supported distribution mirrors."""

    cdrom: str | None = None
    files: list[DownloadFile] = Field(default_factory=list)
    slackware_mirror: str | None = None
    debian_mirror: str | None = None
