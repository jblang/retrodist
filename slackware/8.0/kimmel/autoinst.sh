#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=16384
ROOTDEV=/dev/hda2
ROOTFS=ext2
SETS="a ap d e f gtk k kde n t tcl x xap xv y"
TIMEZONE=US/Central

prepare_disks
slackware_pkgtool_install
