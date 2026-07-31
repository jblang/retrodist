"""Shared static-network configuration."""

from __future__ import annotations

from .base import ConfigModel


class NetworkConfig(ConfigModel):
    """Describe static guest networking shared by installers and guestlib."""

    hostname: str = "localhost"
    domain: str = "retro.net"
    ip: str = "10.0.2.15"
    netmask: str = "255.255.255.0"
    network: str = "10.0.2.0"
    broadcast: str = "10.0.2.255"
    gateway: str = "10.0.2.2"
    nameserver: str = "10.0.2.3"
