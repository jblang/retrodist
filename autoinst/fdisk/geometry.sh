#!/bin/sh
if [ $# -ne 1 ]; then
    echo "usage: $0 device" >&2
    exit 1
fi
DEVICE=$1
(echo p; echo q) | fdisk "$DEVICE"
if [ $? = 0 ]; then
    echo "geometry.sh: fdisk geometry query suceeded"
	exit 0
else
    echo "geometry.sh: fdisk geometry query returned error $?" >&2
	exit $?
fi