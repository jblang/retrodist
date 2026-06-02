init_disk $FDISK_GEOM_2G

DEBIAN_BASE_TARBALL=base1_2.tgz
debian_install_base

HOSTNAME=rex
IPADDR=10.0.2.112
ETCPATH=$ROOTMOUNT/etc
configure_networking
