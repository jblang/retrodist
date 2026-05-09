#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=16384
ROOTDEV=/dev/hda2
ROOTFS=ext2

FDISK_GEOM="$FDISK_GEOM_8G"
prepare_disks

SETS="a ap d e f gtk k kde n t tcl x xap xv y"
TIMEZONE=US/Central
slackware_pkgtool_install
