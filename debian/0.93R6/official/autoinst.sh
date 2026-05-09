#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=65536
ROOTDEV=/dev/hda2
ROOTFS=ext2

FDISK_GEOM="$FDISK_GEOM_500M"
prepare_disks

DEBIAN_PREPARE_FUNCTION=prepare_base_system_093r6
DEBIAN_OPTIONAL_LILO=1
debian_install_base

HOSTNAME=debra
IPADDR=10.0.2.93
ETCPATH=$ROOTMOUNT/etc
configure_networking

debian_install_packages_tree
