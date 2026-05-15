FDISK_GEOM_500M="1 128 129 1015"
FDISK_GEOM_2G="1 17 18 520"
FDISK_GEOM_8G="1 17 18 1044"

fdisk_commands() {
    echo "n"    # add a new partition
    echo "p"    # make the swap partition primary
    echo "1"    # assign partition number 1 to swap
    echo "$1"   # start the swap partition at the requested cylinder
    echo "$2"   # end the swap partition at the requested cylinder
    echo "n"    # add the root partition
    echo "p"    # make the root partition primary
    echo "2"    # assign partition number 2 to root
    echo "$3"   # start the root partition at the requested cylinder
    echo "$4"   # end the root partition at the requested cylinder
    echo "t"    # change the swap partition type
    echo "1"    # select partition 1 for the type change
    echo "82"   # set partition 1 to Linux swap
    echo "t"    # change the root partition type
    echo "2"    # select partition 2 for the type change
    echo "83"   # set partition 2 to a Linux native filesystem
    echo "w"    # write the partition table to disk
    echo       # submit a final blank line to fdisk
}

prepare_disk() {
    FDDEV=$1
    if [ -z "$FDISK_GEOM" ]; then
        echo "No FDISK_GEOM set; aborting."
        exit 1
    fi
    if [ -z "$FDDEV" ]; then
        if [ -z "$FDISK_DEVICE" ]; then
            FDDEV=hda
        else
            FDDEV=$FDISK_DEVICE
        fi
    fi

    set -- $FDISK_GEOM
    if [ $# -ne 4 ]; then
        echo "Invalid FDISK_GEOM: $FDISK_GEOM"
        exit 1
    fi

    fdisk_commands "$1" "$2" "$3" "$4" | fdisk "/dev/$FDDEV" > /dev/null
}

prepare_disks() {
    echo "### Creating partitions..."
    if [ -z "$FDISK_DEVICE" ]; then
        FDISK_DEVICE=hda
    fi
    prepare_disk "$FDISK_DEVICE"
    fdisk -l

    echo "### Initializing swap..."
    mkswap "$SWAPDEV" "$SWAPSIZE"
    swapon "$SWAPDEV"

    echo "### Initializing root filesystem..."
    case $ROOTFS in
        ext2 )  mke2fs "$ROOTDEV" ;;
        * )     echo "Unknown filesystem $ROOTFS"; exit 1;;
    esac

    mount -t "$ROOTFS" "$ROOTDEV" "$ROOTMOUNT"
    mkdir -p "$ROOTMOUNT/tmp"

    echo "### Creating fstab..."
    cat > "$ROOTMOUNT/fstab.tmp" <<EOF
$ROOTDEV		/		$ROOTFS	defaults	0	1
$SWAPDEV		none		swap		sw		0	0
none			/proc		proc		defaults	0	0
EOF
}
