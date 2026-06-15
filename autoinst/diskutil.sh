# Write the installed kernel to a boot floppy and set its root device.
make_boot_floppy() {
    BOOTFLOPPYDEV=${BOOTFLOPPYDEV:-/dev/fd0}
    BOOTKERNEL=${BOOTKERNEL:-$ROOTMOUNT/Image}
    log_info "Creating boot floppy on $BOOTFLOPPYDEV..."
    log_info "Boot floppy configuration:"
    log_info "  BOOTFLOPPYDEV=$BOOTFLOPPYDEV"
    log_info "  BOOTKERNEL=$BOOTKERNEL"
    log_info "  ROOTDEV=$ROOTDEV"

    if [ ! -f "$BOOTKERNEL" ]; then
        log_error "Installed kernel $BOOTKERNEL not found."
        return 1
    fi

    umount /user >/dev/null 2>&1
    log_attention "Reattach boot.img and press ENTER."
    read line

    dd if="$BOOTKERNEL" of="$BOOTFLOPPYDEV"
    if [ $? -ne 0 ]; then
        log_error "Boot floppy write failed."
        return 1
    fi

    rootdev "$BOOTFLOPPYDEV" "$ROOTDEV"
    if [ $? -ne 0 ]; then
        log_error "rootdev failed for $BOOTFLOPPYDEV."
        return 1
    fi

    return 0
}

# List fdisk partitions with the geometry for the requested disk.
fdisk_list_partitions() {
    log_debug "Listing partitions on $1"
    (
        echo p
        echo q
    ) | fdisk $1 2>&1
}

# Extract the partition table header from fdisk output.
fdisk_get_header() {
    sed -n '/^[ 	]*Device[ 	]/p'
}

# Extract one partition line from fdisk output.
fdisk_get_partition() {
    sed -n "\\|^$1[ 	]|p"
}

# Log raw fdisk output to stderr and the install log.
fdisk_log_output() {
    log_info "fdisk output:"
    echo "$1" >&2
    if [ -n "$AUTOINST_LOG" ]; then
        echo "$1" >>"$AUTOINST_LOG"
    fi
}

# Detect the old or new fdisk partition table column format.
fdisk_detect_format() {
    if [ "$5" = "Blocks" ]; then
        echo "new"
    elif [ "$6" = "Blocks" ]; then
        echo "old"
    else
        echo "unknown"
    fi
}

# Parse a partition block count from one fdisk partition line.
fdisk_parse_blocks() {
    # eat the boot column's asterisk if it exists
    if [ "$2" = "*" ]; then
        shift
    fi
    # FDISK_HEADER must be set before calling fdisk_parse_blocks
    case $(fdisk_detect_format $FDISK_HEADER) in
    old) shift ;;  # eat extra column in old format
    new) ;;        # use new format columns as-is
    *) return 1 ;; # unknown format
    esac
    # fourth remaining column is the blocks; remove + suffix if present
    echo $4 | sed 's/+$//'
    return 0
}

# Parse existing swap and root partition metadata from fdisk output.
fdisk_parse_partitions() {
    log_info "Checking existing partitions on $DISKDEV..."
    FDISK_OUTPUT=$(fdisk_list_partitions $1)
    FDISK_HEADER=$(echo "$FDISK_OUTPUT" | fdisk_get_header)
    log_debug "Detected fdisk header: $FDISK_HEADER"
    FDISK_SWAPLINE=$(echo "$FDISK_OUTPUT" | fdisk_get_partition $SWAPDEV)
    FDISK_ROOTLINE=$(echo "$FDISK_OUTPUT" | fdisk_get_partition $ROOTDEV)
    if [ -n "$FDISK_SWAPLINE" -a -n "$FDISK_ROOTLINE" ]; then
        fdisk_log_output "$FDISK_OUTPUT"
    fi
    if [ -n "$FDISK_SWAPLINE" ]; then
        SWAPBLOCKS=$(fdisk_parse_blocks $FDISK_SWAPLINE)
        log_info "Found existing swap partition $SWAPDEV with $SWAPBLOCKS blocks."
    else
        log_info "No existing swap partition found on $DISKDEV."
    fi
    if [ -n "$FDISK_ROOTLINE" ]; then
        ROOTBLOCKS=$(fdisk_parse_blocks $FDISK_ROOTLINE)
        log_info "Found existing root partition $ROOTDEV with $ROOTBLOCKS blocks."
    else
        log_info "No existing root partition found on $DISKDEV."
    fi
}

# Emit fdisk commands to create one primary partition.
fdisk_new_primary() {
    echo "n"  # add a new partition
    echo "p"  # make primary partition
    echo "$1" # partition number
    echo "$2" # start cylinder
    echo "$3" # end cylinder
}

# Emit fdisk commands to set a partition type.
fdisk_set_type() {
    echo "t" # change partition type
    echo $1  # partition number
    echo $2  # partition type
}

# Emit the full fdisk command stream for the swap/root layout.
fdisk_commands() {
    fdisk_new_primary 1 $1 $2
    fdisk_new_primary 2 $3 $4
    # run all create commands before setting types to ensure consistent prompts
    fdisk_set_type 1 82
    fdisk_set_type 2 83
    echo "p" # display the current partition table
    echo "w" # write the partition table to disk
    echo     # submit a final blank line to fdisk
}

# Return success when the argument contains only decimal digits.
fdisk_is_number() {
    case "$1" in
    "" | *[!0123456789]*) return 1 ;;
    *) return 0 ;;
    esac
}

# Parse heads, sectors, and cylinders for the requested disk.
fdisk_parse_disk_geometry() {
    FDISK_GEOM_DEV="$1:"
    shift
    FDISK_HEADS=
    FDISK_SECTORS=
    FDISK_CYLINDERS=
    while [ $# -gt 0 ]; do
        if [ "$2" = "heads," -a "$6" = "cylinders" ]; then
            case "$4" in
            sectors,* | sectors/track,*)
                FDISK_HEADS=$1
                FDISK_SECTORS=$3
                FDISK_CYLINDERS=$5
                return 0
                ;;
            esac
        elif [ "$1" = "Disk" -a "$2" = "$FDISK_GEOM_DEV" -a "$4" = "heads," -a "$8" = "cylinders" ]; then
            FDISK_HEADS=$3
            FDISK_SECTORS=$5
            FDISK_CYLINDERS=$7
            return 0
        fi
        shift
    done
    return 1
}

# Return the next cylinder for known auto-partition split points.
fdisk_next_cylinder() {
    case "$1" in
    8) echo 9 ;;
    16) echo 17 ;;
    17) echo 18 ;;
    32) echo 33 ;;
    33) echo 34 ;;
    65) echo 66 ;;
    128) echo 129 ;;
    130) echo 131 ;;
    260) echo 261 ;;
    *) echo "" ;;
    esac
}

# Calculate a cylinder count close to the requested swap size.
fdisk_calculate_swap_end() {
    FDISK_HEADS=$1
    FDISK_SECTORS=$2
    FDISK_SWAP_MB=$3
    if ! fdisk_is_number "$FDISK_HEADS" || ! fdisk_is_number "$FDISK_SECTORS" || ! fdisk_is_number "$FDISK_SWAP_MB"; then
        echo ""
        return 1
    fi
    FDISK_SECTORS_PER_CYLINDER=$(expr "$FDISK_HEADS" \* "$FDISK_SECTORS" 2>/dev/null)
    if [ -z "$FDISK_SECTORS_PER_CYLINDER" -o "$FDISK_SECTORS_PER_CYLINDER" -lt 1 ]; then
        echo ""
        return 1
    fi
    FDISK_SWAP_SECTORS=$(expr "$FDISK_SWAP_MB" \* 2048 2>/dev/null)
    FDISK_HALF_CYLINDER=$(expr "$FDISK_SECTORS_PER_CYLINDER" / 2 2>/dev/null)
    expr \( "$FDISK_SWAP_SECTORS" + "$FDISK_HALF_CYLINDER" \) / "$FDISK_SECTORS_PER_CYLINDER" 2>/dev/null
}

# Look up the closest swap end cylinder for common QEMU CHS layouts.
fdisk_default_swap_end() {
    FDISK_HEADS=$1
    FDISK_SECTORS=$2
    if [ -n "$FDISK_SWAP_CYLINDERS" ]; then
        echo "$FDISK_SWAP_CYLINDERS"
        return 0
    fi

    DISK_SWAP_MB=${DISK_SWAP_MB:-128}
    case "$FDISK_HEADS:$FDISK_SECTORS:$DISK_SWAP_MB" in
    16:63:64) echo 130 ;;
    16:63:128) echo 260 ;;
    32:63:64) echo 65 ;;
    32:63:128) echo 130 ;;
    64:63:64) echo 33 ;;
    64:63:128) echo 65 ;;
    128:63:64) echo 16 ;;
    128:63:128) echo 33 ;;
    240:63:64) echo 9 ;;
    240:63:128) echo 17 ;;
    255:63:64) echo 8 ;;
    255:63:128) echo 16 ;;
    *) fdisk_calculate_swap_end "$FDISK_HEADS" "$FDISK_SECTORS" "$DISK_SWAP_MB" ;;
    esac
}

# Detect the default swap/root fdisk geometry for a disk.
fdisk_detect_geometry() {
    log_info "Detecting disk geometry for $1..."
    FDISK_DETECT_DISK=$1
    FDISK_OUTPUT=$(fdisk_list_partitions $1)
    FDISK_HEADS=
    FDISK_SECTORS=
    FDISK_CYLINDERS=
    FDISK_SWAP_END=
    set -- $FDISK_OUTPUT

    fdisk_parse_disk_geometry "$FDISK_DETECT_DISK" "$@"
    if [ -n "$FDISK_HEADS" -a -n "$FDISK_SECTORS" -a -n "$FDISK_CYLINDERS" ]; then
        FDISK_SWAP_END=$(fdisk_default_swap_end $FDISK_HEADS $FDISK_SECTORS $FDISK_CYLINDERS)
    else
        FDISK_SWAP_END=${FDISK_SWAP_CYLINDERS:-17}
    fi

    if [ -z "$FDISK_CYLINDERS" ]; then
        fdisk_log_output "$FDISK_OUTPUT"
        log_error "Unable to detect disk cylinders from fdisk output."
        return 1
    fi
    if [ -z "$FDISK_SWAP_END" -o "$FDISK_SWAP_END" -lt 1 -o "$FDISK_SWAP_END" -ge "$FDISK_CYLINDERS" ]; then
        log_error "Invalid detected geometry: swap end '$FDISK_SWAP_END', cylinders '$FDISK_CYLINDERS'."
        return 1
    fi

    FDISK_ROOT_START=$(fdisk_next_cylinder "$FDISK_SWAP_END")
    if [ -z "$FDISK_ROOT_START" ]; then
        FDISK_ROOT_START=$(expr "$FDISK_SWAP_END" + 1 2>/dev/null)
        if [ -z "$FDISK_ROOT_START" ]; then
            log_error "Unable to calculate root partition start cylinder."
            return 1
        fi
    fi

    log_info "Detected geometry: heads=$FDISK_HEADS sectors=$FDISK_SECTORS cylinders=$FDISK_CYLINDERS"
    echo "1 $FDISK_SWAP_END $FDISK_ROOT_START $FDISK_CYLINDERS"
}

# Create swap and root partitions using explicit fdisk geometry.
fdisk_partition() {
    log_info "Creating partitions..."

    if [ $# -ne 4 ]; then
        log_error "Invalid geometry: '$*'; must be 'swapstart swapend rootstart rootend'."
        exit 1
    fi

    log_info "Partition geometry:"
    log_info "  swap=$1-$2"
    log_info "  root=$3-$4"
    log_info "Running: fdisk $DISKDEV"
    if [ "$AUTOINST_DEBUG" = "1" ]; then
        fdisk_commands "$@" | fdisk $DISKDEV
    else
        fdisk_commands "$@" | fdisk $DISKDEV >/dev/null 2>&1
    fi

    if [ -n "$FDISK_REBOOT" ]; then
        log_div
        sync
        log_attention "Partition table written; reboot required."
        log_attention "Reattach boot.img and press Ctrl-Alt-Del in the VM to reboot."
        exit 0
    fi
}

# Format and enable the swap partition.
format_swap() {
    if [ -z "$SWAPBLOCKS" ]; then
        log_error "Error formatting swap on $SWAPDEV: SWAPBLOCKS not set"
        exit 1
    fi
    log_info "Formatting swap partition..."
    if [ "$AUTOINST_DEBUG" = "1" ]; then
        mkswap "$SWAPDEV" "$SWAPBLOCKS"
    else
        mkswap "$SWAPDEV" "$SWAPBLOCKS" >/dev/null 2>&1
    fi
    swapon "$SWAPDEV"
}

# Format and mount the root filesystem.
format_root() {
    log_info "Formatting root filesystem $ROOTDEV..."
    if [ -z "$ROOTBLOCKS" ]; then
        log_error "Error formatting root filesystem on $ROOTDEV: ROOTBLOCKS not set"
        exit 1
    fi
    case $ROOTFS in
    ext2)
        if [ "$AUTOINST_DEBUG" = "1" ]; then
            mke2fs "$ROOTDEV"
        else
            mke2fs "$ROOTDEV" >/dev/null 2>&1
        fi
        ;;
    ext)
        if [ "$AUTOINST_DEBUG" = "1" ]; then
            mkefs "$ROOTDEV" "$ROOTBLOCKS"
        else
            mkefs "$ROOTDEV" "$ROOTBLOCKS" >/dev/null 2>&1
        fi
        ;;
    *)
        log_error "Unknown filesystem $ROOTFS"
        exit 1
        ;;
    esac
    if [ $? -ne 0 ]; then
        log_error "Error running creating root filesystem."
        exit 1
    fi
    log_info "Mounting root filesystem $ROOTDEV on $ROOTMOUNT..."
    mount -t "$ROOTFS" "$ROOTDEV" "$ROOTMOUNT"
    if [ $? -ne 0 ]; then
        log_error "Error mounting root filesystem."
        exit 1
    fi
    log_debug "Ensuring directory exists: $ROOTMOUNT/tmp"
    mkdir -p "$ROOTMOUNT/tmp"
}

# Write the temporary fstab used by install helpers.
create_fstab() {
    log_info "Creating file: $ROOTMOUNT/fstab.tmp"
    cat >"$ROOTMOUNT/fstab.tmp" <<EOF
$ROOTDEV		/		$ROOTFS	defaults	0	1
$SWAPDEV		none		swap		sw		0	0
none			/proc		proc		defaults	0	0
EOF
}

# Detect, partition, format, mount, and initialize the target disk.
disk_init() {
    DISKDEV=${DISKDEV:-/dev/hda}
    SWAPPART=${SWAPPART:-1}
    ROOTPART=${ROOTPART:-2}
    SWAPDEV=${SWAPDEV:-$DISKDEV$SWAPPART}
    ROOTDEV=${ROOTDEV:-$DISKDEV$ROOTPART}
    ROOTFS=${ROOTFS:-ext2}
    log_info "Disk configuration:"
    log_info "  DISKDEV=$DISKDEV"
    log_info "  SWAPPART=$SWAPPART"
    log_info "  ROOTPART=$ROOTPART"
    log_info "  SWAPDEV=$SWAPDEV"
    log_info "  ROOTDEV=$ROOTDEV"
    log_info "  ROOTFS=$ROOTFS"
    log_div
    fdisk_parse_partitions "$DISKDEV"
    if [ -z "$SWAPBLOCKS" -o -z "$ROOTBLOCKS" ]; then
        log_div
        log_info "Initializing partitions..."
        # partition if root and swap filesystems don't already exist
        if [ $# -eq 0 ]; then
            FDISK_PARTITION_GEOMETRY=$(fdisk_detect_geometry "$DISKDEV")
            if [ $? -ne 0 ]; then
                exit 1
            fi
            fdisk_partition $FDISK_PARTITION_GEOMETRY
        else
            fdisk_partition "$@"
        fi
        fdisk_parse_partitions "$DISKDEV"
    fi
    log_div
    format_swap
    format_root
    create_fstab
}
