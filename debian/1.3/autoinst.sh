DISK_SWAP_MB=64
disk_init

DEBIAN_BASE_TARBALL=base1_3.tgz
# Optional override (default America/Los_Angeles): DEBIAN_TIMEZONE=Europe/Berlin
debian_install_base

MOD_ENABLE="serial"
mod_config

NET_HOSTNAME=bo
net_config
