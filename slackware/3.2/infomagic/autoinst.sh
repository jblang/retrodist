#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=16384
ROOTDEV=/dev/hda2
ROOTFS=ext2

FDISK_GEOM="$FDISK_GEOM_2G"
prepare_disks

SETS="a ap d e f k n t tcl x xap xd xv y"
TIMEZONE=US/Central
slackware_pkgtool_install
