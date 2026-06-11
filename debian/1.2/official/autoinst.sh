DISK_SWAP_MB=64
disk_init

DEBIAN_BASE_TARBALL=base1_2.tgz
debian_install_base

NET_HOSTNAME=rex
NET_ETCPATH=$ROOTMOUNT/etc
NET_MODULE=none
net_config
