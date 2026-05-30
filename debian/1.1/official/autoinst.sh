init_disk $FDISK_GEOM_2G

DEBIAN_BASE_TARBALL=base1_1.tgz
debian_install_base

HOSTNAME=buzz
IPADDR=10.0.2.111
ETCPATH=$ROOTMOUNT/etc
configure_networking
