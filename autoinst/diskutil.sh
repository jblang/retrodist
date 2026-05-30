FDISK_GEOM_500M="1 128 129 1015"
FDISK_GEOM_2G="1 17 18 520"
FDISK_GEOM_8G="1 17 18 1044"

make_boot_floppy() {
    BOOTFLOPPYDEV=${BOOTFLOPPYDEV:-/dev/fd0}
    BOOTKERNEL=${BOOTKERNEL:-$ROOTMOUNT/Image}
    echo "### Creating boot floppy on $BOOTFLOPPYDEV..."

    if [ ! -f "$BOOTKERNEL" ]; then
        echo "Installed kernel $BOOTKERNEL not found."
        return 1
    fi
    
    umount /user >/dev/null 2>&1
    echo "Reattach boot.img and press ENTER."
    read line

    dd if="$BOOTKERNEL" of="$BOOTFLOPPYDEV"
    if [ $? -ne 0 ]; then
        echo "Boot floppy write failed."
        return 1
    fi

    rootdev "$BOOTFLOPPYDEV" "$ROOTDEV"
    if [ $? -ne 0 ]; then
        echo "rootdev failed for $BOOTFLOPPYDEV."
        return 1
    fi

    return 0
}

fdisk_list_partitions() {
    # workaround for missing -l option on ancient fdisk
    (echo p; echo q) | fdisk $1
}

fdisk_get_header() {
    # filter fdisk output for the header
    sed -n '/^[ 	]*Device[ 	]/p'    
}

fdisk_get_partition() {
    # filter fdisk output for the specified partition
    sed -n "\\|^$1[ 	]|p"
}

fdisk_detect_format() {
    # detect the fdisk partition table's format using position of Blocks column
    if [ "$5" = "Blocks" ]; then
        echo "new"
    elif [ "$6" = "Blocks" ]; then
        echo "old"
    else
        echo "unknown"
    fi
}

fdisk_parse_blocks() {
    # eat the boot column's asterisk if it exists
    if [ "$2" = "*" ]; then
        shift
    fi
    # FDISK_HEADER must be set before calling fdisk_parse_blocks
    case $(fdisk_detect_format $FDISK_HEADER) in
        old ) shift ;;  # eat extra column in old format
        new ) ;;        # use new format columns as-is
        * ) return 1 ;; # unknown format
    esac
    # fourth remaining column is the blocks; remove + suffix if present
    echo $4 | sed 's/+$//'
    return 0
}

fdisk_parse_partitions() {
    echo "### Checking existing partitions on $DISKDEV..."
    # parse the existing partitions from fdisk output
    FDISK_OUTPUT=$(fdisk_list_partitions $1)
    FDISK_HEADER=$(echo "$FDISK_OUTPUT" | fdisk_get_header)
    FDISK_SWAPLINE=$(echo "$FDISK_OUTPUT" | fdisk_get_partition $SWAPDEV)
    if [ -n "$FDISK_SWAPLINE" ]; then
        SWAPBLOCKS=$(fdisk_parse_blocks $FDISK_SWAPLINE)
        echo "Found existing swap partition $SWAPDEV with $SWAPBLOCKS blocks."
    else
        echo "No existing swap partition found on $DISKDEV."
    fi
    FDISK_ROOTLINE=$(echo "$FDISK_OUTPUT" | fdisk_get_partition $ROOTDEV)
    if [ -n "$FDISK_ROOTLINE" ]; then
        ROOTBLOCKS=$(fdisk_parse_blocks $FDISK_ROOTLINE)
        echo "Found existing root partition $ROOTDEV with $ROOTBLOCKS blocks."
    else
        echo "No existing root partition found on $DISKDEV."
    fi
}

fdisk_new_primary() {
    echo "n"    # add a new partition
    echo "p"    # make primary partition
    echo "$1"   # partition number
    echo "$2"   # start cylender
    echo "$3"   # end cylender
}

fdisk_set_type() {
    echo "t"    # change partition type
    echo $1     # partition number
    echo $2     # partition type
}

fdisk_commands() {
    fdisk_new_primary 1 $1 $2
    fdisk_new_primary 2 $3 $4
    # run all create commands before setting types to ensure consistent prompts
    fdisk_set_type 1 82
    fdisk_set_type 2 83
    echo "p"    # display the current partition table
    echo "w"    # write the partition table to disk
    echo        # submit a final blank line to fdisk
}

fdisk_partition() {
    echo "### Creating partitions..."

    if [ $# -ne 4 ]; then
        echo "Invalid geometry: '$*'; must be 'swapstart swapend rootstart rootend'."
        exit 1
    fi

    fdisk_commands "$@" | fdisk $DISKDEV

    if [ -n "$FDISK_REBOOT" ]; then
        sync
        echo
        echo "### Partition table written; reboot required."
        echo "### Reattach boot.img and press Ctrl-Alt-Del in the VM to reboot."
        exit 0
    fi
}

format_swap() {
    if [ -z "$SWAPBLOCKS" ]; then
        echo "Error formatting swap on $SWAPDEV: SWAPBLOCKS not set"
        exit 1
    fi
    echo "### Formatting swap partition..."
    mkswap "$SWAPDEV" "$SWAPBLOCKS"
    swapon "$SWAPDEV"
}

format_root() {
    echo "### Formatting root filesystem $ROOTDEV..."
    if [ -z "$ROOTBLOCKS" ]; then
        echo "Error formatting root filesystem on $ROOTDEV: ROOTBLOCKS not set"
        exit 1
    fi
    case $ROOTFS in
        ext2 )  mke2fs "$ROOTDEV" ;;
        ext )   mkefs "$ROOTDEV" "$ROOTBLOCKS" ;;
        * )     echo "Unknown filesystem $ROOTFS"; exit 1;;
    esac
    if [ $? -ne 0 ]; then
        echo "Error running creating root filesystem."
        exit 1
    fi
    echo "### Mounting root filesystem $ROOTDEV on $ROOTMOUNT..."
    mount -t "$ROOTFS" "$ROOTDEV" "$ROOTMOUNT"
    if [ $? -ne 0 ]; then
        echo "Error mounting root filesystem."
        exit 1
    fi
    mkdir -p "$ROOTMOUNT/tmp"
 }

create_fstab() {
    echo "### Creating fstab..."
    cat > "$ROOTMOUNT/fstab.tmp" <<EOF
$ROOTDEV		/		$ROOTFS	defaults	0	1
$SWAPDEV		none		swap		sw		0	0
none			/proc		proc		defaults	0	0
EOF
}

init_disk() {
    DISKDEV=${DISKDEV:-/dev/hda}
    SWAPPART=${SWAPPART:-1}
    ROOTPART=${ROOTPART:-2}
    SWAPDEV=${SWAPDEV:-$DISKDEV$SWAPPART}
    ROOTDEV=${ROOTDEV:-$DISKDEV$ROOTPART}
    ROOTFS=${ROOTFS:-ext2}
    fdisk_parse_partitions "$DISKDEV"
    if [  -z "$SWAPBLOCKS" -o -z "$ROOTBLOCKS" ]; then
        # partition if root and swap filesystems don't already exist
        fdisk_partition "$@"
        fdisk_parse_partitions "$DISKDEV"
    fi
    format_swap
    format_root
    create_fstab
}