#!/bin/sh

PATH=$PATH:/retro/bin

ROOTFS=ext
FDISK_REBOOT=1

init_disk $FDISK_GEOM_500M

SLS_INSTALL_MODE=all
sls_sysinstall
make_boot_floppy
