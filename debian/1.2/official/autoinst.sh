init_disk $FDISK_GEOM_2G

DEBIAN_BASE_TARBALL=base1_2.tgz
debian_install_base

NET_HOSTNAME=rex
NET_ETCPATH=$ROOTMOUNT/etc
net_config
