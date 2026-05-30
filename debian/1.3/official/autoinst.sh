#!/bin/sh

init_disk $FDISK_GEOM_2G

DEBIAN_BASE_TARBALL=base1_3.tgz
DEBIAN_INITTAB_FALLBACK=etc/init.d/inittab
DEBIAN_ROOT_HOOK=.bash_profile
DEBIAN_ROOT_TARBALL=/etc/root.sh.tar.gz
DEBIAN_TAR_EXTRACTOR="star -x"
DEBIAN_INSTALL_DRIVERS=1
DEBIAN_SKIP_SETUP_SH=1
debian_install_base

HOSTNAME=debra
IPADDR=10.0.2.93
ETCPATH=$ROOTMOUNT/etc
configure_networking
