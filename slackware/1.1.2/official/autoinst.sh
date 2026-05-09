#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=16384
ROOTDEV=/dev/hda2
ROOTFS=ext2

FDISK_GEOM="$FDISK_GEOM_500M"
prepare_disks

SETS="a ap d e f i iv n t tcl oi oop x xap xd xv y"
TIMEZONE=US/Central
slackware_pkgtool_install
