#!/bin/sh
if [ $# -ne 5 ]; then
    echo "usage: swaproot.sh device swap_start swap_end root_start root_end" >&2
    exit 1
fi
DEVICE=$1
SWAP_START=$2
SWAP_END=$3
ROOT_START=$4
ROOT_END=$5
(
    echo n              # new swap partition
    echo p              # primary
    echo 1              # partition number
    echo "$SWAP_START"  # first cylinder
    echo "$SWAP_END"    # last cylinder
    echo n              # new root partition
    echo p              # primary
    echo 2              # partition number
    echo "$ROOT_START"  # first cylinder
    echo "$ROOT_END"    # last cylinder
    echo t              # partition type
    echo 1              # swap partition
    echo 82             # Linux swap
    echo t              # partition type
    echo 2              # root partition
    echo 83             # Linux native
    echo p              # print table
    echo w              # write table
    echo
) | fdisk "$DEVICE"
if [ $? = 0 ]; then
    echo "swaproot.sh: created swap partition ${DEVICE}1 from $SWAP_START-$SWAP_END"
	echo "swaproot.sh: created root partition ${DEVICE}2 from $ROOT_START-$ROOT_END"
	exit 0
else
    echo "swaproot.sh: fdisk partition creation returned error $?" >&2
	exit $?
fi