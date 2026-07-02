#!/bin/sh
#
# Build the default swap/root fdisk layout during unattended installs.

if [ $# -ne 2 ]; then
    echo "usage: $0 device swap_mb" >&2
    exit 1
fi
DISK=$1
SWAP_MB=$2

FDISK_OUTPUT=$( (echo p; echo q) | fdisk "$DISK" 2>&1 )

HEADS=
SECTORS=
CYLINDERS=
set -- $FDISK_OUTPUT
while [ $# -gt 0 ]; do
    if [ "$2" = "heads," -a "$6" = "cylinders" ]; then
        case "$4" in
        sectors,* | sectors/track,*)
            HEADS=$1
            SECTORS=$3
            CYLINDERS=$5
            break
            ;;
        esac
    fi
    shift
done

if [ -z "$HEADS" -o -z "$SECTORS" -o -z "$CYLINDERS" ]; then
    echo "could not detect geometry for $DISK" >&2
    echo "$FDISK_OUTPUT" >&2
    exit 1
fi

if [ -x /bin/expr ]; then
    # calculate using expr
	SECTORS_PER_CYLINDER=$(expr $HEADS * $SECTORS)
	SWAP_SECTORS=$(expr $SWAP_MB * 2048)
	HALF_CYLINDER=$(expr $SECTORS_PER_CYLINDER / 2)
	SWAP_END=$(expr $(expr $SWAP_SECTORS + $HALF_CYLINDER) / $SECTORS_PER_CYLINDER)
	ROOT_START=$(expr $SWAP_END + 1)
elif [ -x /usr/bin/perl ]; then
    # calculate using perl (for Red Hat 1.x-3.x)
    SECTORS_PER_CYLINDER=$(perl -e "print $HEADS * $SECTORS")
    SWAP_SECTORS=$(perl -e "print $SWAP_MB * 2048")
    HALF_CYLINDER=$(perl -e "print int($SECTORS_PER_CYLINDER / 2)")
    SWAP_END=$(perl -e "print int(($SWAP_SECTORS + $HALF_CYLINDER) / $SECTORS_PER_CYLINDER)")
    ROOT_START=$(perl -e "print $SWAP_END + 1")
elif [ -x /bin/math ]; then
    # calculate using Debian /bin/math command
    SECTORS_PER_CYLINDER=$(math $HEADS $SECTORS mul)
    SWAP_SECTORS=$(math $SWAP_MB 2048 mul)
    HALF_CYLINDER=$(math $SECTORS_PER_CYLINDER 2 div)
    SWAP_END=$(math $SWAP_SECTORS $HALF_CYLINDER add $SECTORS_PER_CYLINDER div)
    ROOT_START=$(math $SWAP_END 1 add)
elif [ -n "$BASH_VERSION" ]; then
    # calculate using bash math expressions (quoted to avoid syntax errors on sh)
    eval '
        SECTORS_PER_CYLINDER=$((HEADS * SECTORS))
        SWAP_SECTORS=$((SWAP_MB * 2048))
        HALF_CYLINDER=$((SECTORS_PER_CYLINDER / 2))
        SWAP_END=$(((SWAP_SECTORS + HALF_CYLINDER) / SECTORS_PER_CYLINDER))
        ROOT_START=$((SWAP_END + 1))
    '
else
    echo "no math tools available for partition calculations" >&2
    exit 1
fi

if [ -z "$SWAP_END" -o -z "$ROOT_START" -o -z "$CYLINDERS" ]; then
    echo "partition calculations did not produce required values" >&2
    exit 1
fi

if [ -z "$SWAP_END" -o "$SWAP_END" -lt 1 -o "$SWAP_END" -ge "$CYLINDERS" ]; then
    echo "swap size is too large for $DISK geometry" >&2
    exit 1
fi

(
    echo n              # new swap partition
    echo p              # primary
    echo 1              # partition number
    echo 1              # first cylinder
    echo "$SWAP_END"    # last cylinder
    echo n              # new root partition
    echo p              # primary
    echo 2              # partition number
    echo "$ROOT_START"  # first cylinder
    echo "$CYLINDERS"   # last cylinder
    echo t              # partition type
    echo 1              # swap partition
    echo 82             # Linux swap
    echo t              # partition type
    echo 2              # root partition
    echo 83             # Linux native
    echo p              # print table
    echo w              # write table
    echo
) | fdisk "$DISK"

if [ $? -ne 0 ]; then
    echo "fdisk $DISK failed" >&2
    exit 1
fi

echo "partitioned $DISK: swap=${SWAP_MB}MB cylinders=1-$SWAP_END, root cylinders=$ROOT_START-$CYLINDERS"
