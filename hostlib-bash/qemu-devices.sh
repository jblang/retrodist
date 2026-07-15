# shellcheck shell=bash
# QEMU startup media, disks, serial, parallel, and device reporting.

# Selects install-time media overrides and boot order.
device_select_media() {
    log_debug "Selecting startup media"
    QEMU_FDA_OVERRIDE=
    QEMU_HDC_OVERRIDE=

    if [[ ($COMMAND == "install" || $COMMAND == "boot") && -f boot.img ]]; then
        QEMU_FDA_OVERRIDE=boot.img
        log_debug "Using boot.img as first floppy"
    fi

    if [[ ($COMMAND == "install" || $COMMAND == "boot") && ! -f hdc.iso && -f install.iso ]]; then
        QEMU_HDC_OVERRIDE=install.iso
        log_debug "Using install.iso as CD-ROM"
    fi

    if [[ $COMMAND != "install" ]]; then
        return
    fi

    if device_has_boot_floppy; then
        # shellcheck disable=SC2034 # Read by qemu-command.sh.
        QEMU_BOOT_ORDER="order=a"
        log_debug "Install boot order: floppy"
    elif device_has_cdrom; then
        # shellcheck disable=SC2034 # Read by qemu-command.sh.
        QEMU_BOOT_ORDER="order=d"
        log_debug "Install boot order: CD-ROM"
    else
        log_warn "Install command has no floppy or CD-ROM startup media"
    fi
}

# Tests whether the first floppy has default or override media.
device_has_boot_floppy() {
    [[ -f fda.img || -n "${QEMU_FDA_OVERRIDE:-}" ]]
}

# Tests whether the CD-ROM has default or override media.
device_has_cdrom() {
    [[ -f hdc.iso || -n "${QEMU_HDC_OVERRIDE:-}" ]]
}

# Tests whether any bootable startup media exists.
device_has_startup_media() {
    device_has_boot_floppy || device_has_cdrom
}

# Creates the primary hard disk when startup media is available.
device_ensure_primary_disk() {
    local create_options
    if [[ ! -f hda.img ]]; then
        if device_has_startup_media; then
            log_info "Creating primary disk hda.img ($QEMU_HD_SIZE, $QEMU_HD_FORMAT)"
            create_options=()
            if [[ -n "${QEMU_HD_CREATE_OPTIONS:-}" ]]; then
                create_options=(-o "$QEMU_HD_CREATE_OPTIONS")
            fi
            qemu-img create -f "$QEMU_HD_FORMAT" "${create_options[@]}" hda.img "$QEMU_HD_SIZE"
        else
            return 1
        fi
    else
        log_debug "Primary disk already exists: hda.img"
    fi
}

# Maps drive names to QEMU interface indexes.
device_drive_index() {
    case "$1" in
    hda | fda) echo 0 ;;
    hdb | fdb) echo 1 ;;
    hdc) echo 2 ;;
    hdd) echo 3 ;;
    esac
}

# Adds one -drive argument to QEMU_DRIVES.
device_add_drive() {
    local interface=$1
    local index=$2
    local format=$3
    local options=$4

    QEMU_DRIVES+=(-drive "if=$interface,index=$index,format=$format,$options")
}

# Builds drive attachments from existing images, ISOs, and FAT directories.
device_build_drives() {
    local drive index interface format drive_options image_file iso_file
    log_debug "Building guest drive list"
    QEMU_DRIVES=()
    for drive in fda fdb hda hdb hdc hdd; do
        image_file=$drive.img
        iso_file=$drive.iso
        if [[ $drive == "fda" && -n "${QEMU_FDA_OVERRIDE:-}" ]]; then
            image_file=$QEMU_FDA_OVERRIDE
        elif [[ $drive == "hdc" && -n "${QEMU_HDC_OVERRIDE:-}" ]]; then
            image_file=
            iso_file=$QEMU_HDC_OVERRIDE
        fi

        index=$(device_drive_index "$drive")
        if [[ $drive = fd* ]]; then
            interface=floppy
            format=raw
        else
            interface=ide
            if [[ -n "$image_file" && -f $image_file ]]; then
                format=$QEMU_HD_FORMAT
            else
                format=raw
            fi
        fi
        drive_options=""
        if [[ $drive == "hda" && -n "${QEMU_HDA_OPTIONS:-}" ]]; then
            drive_options=",$QEMU_HDA_OPTIONS"
        fi
        if [[ -n "$image_file" && -f $image_file ]]; then
            log_debug "Attaching $image_file as $drive"
            device_add_drive "$interface" "$index" "$format" "file=$image_file$drive_options"
        elif [[ -f $iso_file ]]; then
            log_debug "Attaching $iso_file as $drive CD-ROM"
            device_add_drive "$interface" "$index" "$format" "media=cdrom,file=$iso_file"
        elif [[ $drive == "hdb" && -d fat ]]; then
            log_debug "Attaching fat/ as hdb"
            device_add_drive "$interface" "$index" raw "file=fat:rw:fat"
        elif [[ -d $drive ]]; then
            log_debug "Attaching $drive/ as FAT-backed drive"
            device_add_drive "$interface" "$index" raw "file=fat:rw:$drive"
        fi
    done
}

# Builds global floppy-controller options.
device_build_globals() {
    log_debug "Building QEMU global options"
    QEMU_GLOBALS=()
    if [[ -n "$QEMU_FDTYPE_A" ]]; then
        QEMU_GLOBALS+=(-global "isa-fdc.fdtypeA=$QEMU_FDTYPE_A")
    fi
    if [[ -n "$QEMU_FDTYPE_B" ]]; then
        QEMU_GLOBALS+=(-global "isa-fdc.fdtypeB=$QEMU_FDTYPE_B")
    fi
}

# Builds Unix socket chardev arguments for serial or parallel ports.
device_build_socket_chardevs() {
    local array_name=$1
    local option=$2
    local count=$3
    local prefix=$4
    local label=${5:-chardev}
    local i socket

    log_debug "Creating $count $label chardevs"
    eval "$array_name=()"
    for ((i = 0; i < count; i++)); do
        socket="$prefix$i.sock"
        rm -f "$socket"
        eval "$array_name+=( \"\$option\" \"unix:\$socket,server=on,wait=off\" )"
    done
}

# Builds the guest serial ports in the order QEMU numbers them: sockets, then
# QEMU_SERIAL_AUX, then the scripting pipe the serial shell and dialog adapter
# talk to the host over (see serial_start). Set QEMU_SERIAL_PIPE= to disable it.
device_build_serials() {
    device_build_socket_chardevs QEMU_SERIALS -serial "$QEMU_SERIAL_SOCKET_COUNT" "$QEMU_SERIAL_SOCKET_PREFIX" serial
    if [[ -n "${QEMU_SERIAL_AUX:-}" ]]; then
        QEMU_SERIALS+=(-serial "$QEMU_SERIAL_AUX")
    fi
    if [[ -n "${QEMU_SERIAL_PIPE:-}" ]]; then
        log_debug "Creating serial pipe chardev $QEMU_SERIAL_PIPE"
        rm -f "$QEMU_SERIAL_PIPE.in" "$QEMU_SERIAL_PIPE.out"
        mkfifo "$QEMU_SERIAL_PIPE.in" "$QEMU_SERIAL_PIPE.out"
        QEMU_SERIALS+=(-serial "pipe:$QEMU_SERIAL_PIPE")
    fi
}

# Builds guest parallel socket arguments.
device_build_parallels() {
    device_build_socket_chardevs QEMU_PARALLELS -parallel "$QEMU_PARALLEL_SOCKET_COUNT" "$QEMU_PARALLEL_SOCKET_PREFIX" parallel
}

# Creates the FIFO pair used by QEMU's QMP pipe chardev.
device_build_qmp_pipe() {
    if [[ -n "${QEMU_QMP_PIPE:-}" && "$QEMU_QMP_PIPE" != "none" ]]; then
        log_debug "Creating QMP pipe chardev $QEMU_QMP_PIPE"
        rm -f "$QEMU_QMP_PIPE.in" "$QEMU_QMP_PIPE.out"
        rm -rf "$QEMU_QMP_PIPE.lock"
        mkfifo "$QEMU_QMP_PIPE.in" "$QEMU_QMP_PIPE.out"
    fi
}

# Prints guest disk and character device attachments.
device_print() {
    device_print_drives
    echo
    device_print_chardevs
}

# Prints the guest disk attachments.
device_print_drives() {
    local i option value
    local indent=${QEMU_HARDWARE_DETAIL_INDENT:-    }

    echo "💾 Guest disks:"
    if [[ ${#QEMU_DRIVES[@]} -eq 0 ]]; then
        echo "${indent}none"
    else
        for ((i = 0; i < ${#QEMU_DRIVES[@]}; i += 2)); do
            option=${QEMU_DRIVES[$i]}
            value=${QEMU_DRIVES[$((i + 1))]:-}
            echo "${indent}$option $value"
        done
    fi
}

# Prints exported guest character devices.
device_print_chardevs() {
    local printed_chardev=0
    local indent=${QEMU_HARDWARE_DETAIL_INDENT:-    }

    echo "⌨️  Guest character devices:"
    device_print_exported_chardevs "${QEMU_SERIALS[@]}" && printed_chardev=1
    device_print_exported_chardevs "${QEMU_PARALLELS[@]}" && printed_chardev=1
    if [[ $printed_chardev -eq 0 ]]; then
        echo "${indent}none"
    fi
}

# Prints chardev arguments that expose Unix sockets or pipes.
device_print_exported_chardevs() {
    local option printed=1 value
    local indent=${QEMU_HARDWARE_DETAIL_INDENT:-    }

    while [[ $# -ge 2 ]]; do
        option=$1
        value=${2:-}
        case "$value" in
        unix:* | pipe:*)
            echo "${indent}$option $value"
            printed=0
            ;;
        esac
        shift 2
    done
    return "$printed"
}
