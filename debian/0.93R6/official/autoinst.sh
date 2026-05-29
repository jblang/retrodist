#!/bin/sh

init_disk $FDISK_GEOM_500M

DEBIAN_PREPARE_FUNCTION=prepare_base_system_093r6
DEBIAN_OPTIONAL_LILO=1
debian_install_base

HOSTNAME=debra
IPADDR=10.0.2.93
ETCPATH=$ROOTMOUNT/etc
configure_networking

debian_install_packages_tree
