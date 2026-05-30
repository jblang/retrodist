init_disk $FDISK_GEOM_2G

DEBIAN_BASE_TARBALL=base1_2.tgz
DEBIAN_INITTAB_FALLBACK=etc/init.d/inittab
DEBIAN_ROOT_HOOK=.bash_profile
DEBIAN_INSTALL_DRIVERS=1
debian_install_base

HOSTNAME=rex
IPADDR=10.0.2.112
ETCPATH=$ROOTMOUNT/etc
configure_networking
