#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=65536
ROOTDEV=/dev/hda2
ROOTFS=ext2

FDISK_GEOM="$FDISK_GEOM_500M"
prepare_disks

DEBIAN_BASE_STYLE=091
debian_install_base
