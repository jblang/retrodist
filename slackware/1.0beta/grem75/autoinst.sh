#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=16384
ROOTDEV=/dev/hda2
ROOTFS=ext2

echo $PATH

prepare_disks
slackware_sysinstall
