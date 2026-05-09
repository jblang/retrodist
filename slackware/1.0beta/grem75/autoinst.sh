#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=16384
ROOTDEV=/dev/hda2
ROOTFS=ext2

FDISK_GEOM="$FDISK_GEOM_500M"
prepare_disks

slackware_sysinstall
