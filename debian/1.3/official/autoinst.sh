init_disk $FDISK_GEOM_2G

DEBIAN_BASE_TARBALL=base1_3.tgz
debian_install_base

HOSTNAME=bo
IPADDR=10.0.2.113
ETCPATH=$ROOTMOUNT/etc
configure_networking
