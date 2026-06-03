init_disk $FDISK_GEOM_2G

DEBIAN_BASE_TARBALL=base1_1.tgz
DEBIAN_ROOT_HOOK=.configure
DEBIAN_ETH_MODULE=ne
DEBIAN_ETH_MODULE_OPTIONS='io=0x300 irq=9'
debian_install_base

HOSTNAME=buzz
IPADDR=10.0.2.111
ETCPATH=$ROOTMOUNT/etc
configure_networking
