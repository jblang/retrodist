#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=65536
ROOTDEV=/dev/hda2
ROOTFS=ext2

FDISK_GEOM="$FDISK_GEOM_500M"
prepare_disks

DEBIAN_BASE_TARBALL=base1_2.tgz
DEBIAN_INITTAB_FALLBACK=etc/init.d/inittab
DEBIAN_ROOT_HOOK=.bash_profile
DEBIAN_INSTALL_DRIVERS=1
debian_install_base

HOSTNAME=debra
IPADDR=10.0.2.92
ETCPATH=$ROOTMOUNT/etc
configure_networking
