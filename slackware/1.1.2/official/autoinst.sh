#!/bin/sh

init_disk $FDISK_GEOM_500M

SETS="a ap d e f i iv n t tcl oi oop x xap xd xv y"
TIMEZONE=US/Central
slackware_pkgtool_install
