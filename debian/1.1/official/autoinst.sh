init_disk $FDISK_GEOM_2G

DEBIAN_BASE_TARBALL=base1_1.tgz
DEBIAN_ROOT_HOOK=.configure
debian_install_base

NET_HOSTNAME=buzz
NET_ETCPATH=$ROOTMOUNT/etc
NET_MODULE='ne io=0x300 irq=9'
net_config
