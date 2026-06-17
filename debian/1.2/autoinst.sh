DISK_SWAP_MB=64
disk_init

DEBIAN_BASE_TARBALL=base1_2.tgz
# Optional override (default America/Los_Angeles): DEBIAN_TIMEZONE=Europe/Berlin
debian_install_base

MOD_ENABLE="serial"
mod_config

NET_HOSTNAME=rex
# static arp entries to fix flaky networking in 1.2:
NET_GATEWAY_HWADDR=52:55:0a:00:02:02
NET_NAMESERVER_HWADDR=52:55:0a:00:02:03
net_config
