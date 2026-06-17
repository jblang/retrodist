DISK_SWAP_MB=64
disk_init

DEBIAN_BASE_TARBALL=base1_1.tgz
DEBIAN_ROOT_HOOK=.configure
# Optional console/locale overrides (defaults: KEYMAP/SOFTFONT=NONE, TIMEZONE=America/Los_Angeles):
#   DEBIAN_KEYMAP=de-latin1      # a name under /usr/lib/kbd/keytables
#   DEBIAN_SOFTFONT=...          # a name under /usr/lib/kbd/consolefonts
#   DEBIAN_TIMEZONE=Europe/Berlin
debian_install_base

MOD_ENABLE="serial
ne io=0x300 irq=9"
mod_config

NET_HOSTNAME=buzz
net_config
