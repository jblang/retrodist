init_disk $FDISK_GEOM_2G

DEBIAN_BASE_TARBALL=base1_3.tgz
debian_install_base

NET_HOSTNAME=bo
NET_ETCPATH=$ROOTMOUNT/etc
net_config
