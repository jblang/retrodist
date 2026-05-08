#!/bin/sh

SWAPDEV=/dev/hda1
SWAPSIZE=65536
ROOTDEV=/dev/hda2
ROOTFS=ext2

prepare_disks
debian_install_base_091
