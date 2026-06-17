# shellcheck shell=bash
# QEMU configuration, boot, packaging, prerequisite install, and reset helpers.

# Chooses the default QEMU display backend for the host OS.
qemu_default_display() {
    case "$(uname -s)" in
    Darwin)
        echo "-display cocoa,zoom-to-fit=on,zoom-interpolation=on"
        ;;
    *)
        echo "-display gtk"
        ;;
    esac
}

# Warns when the configured QEMU display backend is unavailable.
qemu_warn_missing_display_backend() {
    local backend available
    if [[ -z "$QEMU_DISPLAY" || "$QEMU_DISPLAY" != *"-display "* ]]; then
        return
    fi

    backend=${QEMU_DISPLAY#*-display }
    backend=${backend%%[ ,]*}
    backend=${backend%%=*}
    if [[ -z "$backend" || "$backend" == "none" ]]; then
        return
    fi

    available=$($QEMU_SYSTEM -display help 2>/dev/null || true)
    if [[ -n "$available" && "$available" != *"$backend"* ]]; then
        echo "Warning: $QEMU_SYSTEM does not have the '$backend' display backend installed."
        echo "Install a QEMU UI backend package, or set QEMU_DISPLAY to another backend."
        echo
    fi
}

# Appends a whitespace-separated argument string to QEMU_ARGS.
# Uses read -ra (not eval) so config/env strings cannot trigger command
# substitution or glob expansion; -d '' lets multi-line strings split too.
qemu_append_args_string() {
    local words=()
    if [[ -n "${1:-}" ]]; then
        read -ra words -d '' <<<"$1" || true
        if [[ ${#words[@]} -gt 0 ]]; then
            QEMU_ARGS+=("${words[@]}")
        fi
    fi
}

# Tests whether a TCP port already has a listener.
qemu_port_listening() {
    local port
    port=$1
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

# Verifies that lsof is available for port allocation.
qemu_require_lsof() {
    if ! command -v lsof >/dev/null 2>&1; then
        echo "Missing lsof in PATH; cannot allocate QEMU ports." >&2
        return 1
    fi
}

# Finds the first available port in a 100-port range.
qemu_find_available_port() {
    local base label offset port
    label=$1
    base=$2
    for ((offset = 0; offset <= 99; offset++)); do
        port=$((base + offset))
        if ! qemu_port_listening "$port"; then
            printf '%s\n' "$port"
            return 0
        fi
    done
    echo "No available $label port found from $base through $((base + 99))." >&2
    return 1
}

# Renders QEMU_ARGS as a POSIX shell command line.
qemu_render_command_sh() {
    local arg rendered=
    for arg in "${QEMU_ARGS[@]}"; do
        rendered="$rendered $(shell_quote_word "$arg")"
    done
    printf '%s\n' "${rendered# }"
}

# Renders QEMU_ARGS as a Windows cmd command line for the generated retro.bat.
# Only used by retro_package; never applied to the printed/executed command.
qemu_render_command_cmd() {
    local arg
    local rendered=
    for arg in "${QEMU_ARGS[@]}"; do
        # A literal percent must be doubled in a batch file.
        arg=${arg//%/%%}
        case "$arg" in
        # Whitespace, quotes, or cmd.exe metacharacters: quote the argument so
        # cmd treats them literally, doubling any embedded quotes.
        *[[:space:]\"\&\|\<\>^\(\)]*)
            arg=${arg//\"/\"\"}
            rendered="$rendered \"$arg\""
            ;;
        *)
            rendered="$rendered $arg"
            ;;
        esac
    done
    printf '%s\n' "${rendered# }"
}

# Sets baseline QEMU defaults before distro overrides are sourced.
qemu_base_defaults() {
    # System options
    QEMU_SYSTEM="${QEMU_SYSTEM:-qemu-system-i386}"
    QEMU_PROFILE="${QEMU_PROFILE:-default}"
    QEMU_SMP="${QEMU_SMP:-1}"

    # Storage options
    QEMU_HD_FORMAT="${QEMU_HD_FORMAT:-qcow2}"
    QEMU_HD_CREATE_OPTIONS="${QEMU_HD_CREATE_OPTIONS:-}"
    QEMU_HDA_OPTIONS="${QEMU_HDA_OPTIONS:-}"
    QEMU_FDTYPE_A="${QEMU_FDTYPE_A:-144}"
    QEMU_FDTYPE_B="${QEMU_FDTYPE_B:-144}"
    QEMU_BOOT_ORDER="${QEMU_BOOT_ORDER:-}"

    # Network options
    QEMU_NET_TYPE="${QEMU_NET_TYPE:-user}"
    QEMU_RETRONET="${QEMU_RETRONET:-}"
    QEMU_INTERNET="${QEMU_INTERNET:-}"

    # Serial/parallel ports (chardev)
    QEMU_SERIAL_SOCKET_COUNT="${QEMU_SERIAL_SOCKET_COUNT:-4}"
    QEMU_SERIAL_SOCKET_PREFIX="${QEMU_SERIAL_SOCKET_PREFIX:-ttyS}"
    QEMU_PARALLEL_SOCKET_COUNT="${QEMU_PARALLEL_SOCKET_COUNT:-1}"
    QEMU_PARALLEL_SOCKET_PREFIX="${QEMU_PARALLEL_SOCKET_PREFIX:-lp}"

    # QEMU monitor port and QMP socket
    QEMU_MONITOR_BASE="${QEMU_MONITOR_BASE:-5555}"
    QEMU_MONITOR_PORT="${QEMU_MONITOR_PORT:-}"
    QEMU_QMP_SOCKET="${QEMU_QMP_SOCKET:-qmp.sock}"

    # Guest port forwards
    QEMU_SSH_BASE="${QEMU_SSH_BASE:-2200}"
    QEMU_SSH_PORT="${QEMU_SSH_PORT:-}"
    QEMU_TELNET_BASE="${QEMU_TELNET_BASE:-2300}"
    QEMU_TELNET_PORT="${QEMU_TELNET_PORT:-}"
    QEMU_HTTP_BASE="${QEMU_HTTP_BASE:-8000}"
    QEMU_HTTP_PORT="${QEMU_HTTP_PORT:-}"

    # Install scripting
    QEMU_INSTALL_SCRIPT="${QEMU_INSTALL_SCRIPT:-}"
}

# Applies hardware defaults for a named distro-era profile.
qemu_apply_profile() {
    QEMU_PROFILE=${1:-${QEMU_PROFILE:-default}}
    case $QEMU_PROFILE in
    default)
        QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
        QEMU_RAM="${QEMU_RAM:-16M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-500M}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
        ;;
    linux-0.99)
        QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
        QEMU_RAM="${QEMU_RAM:-64M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-500M}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
        ;;
    linux-1.0)
        QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
        QEMU_RAM="${QEMU_RAM:-64M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-512M}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
        ;;
    linux-1.2)
        QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
        QEMU_RAM="${QEMU_RAM:-64M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-2G}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
        QEMU_ACCEL="${QEMU_ACCEL:--accel tcg}"
        ;;
    linux-2.0-isa)
        QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
        QEMU_RAM="${QEMU_RAM:-64M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-2G}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
        ;;
    linux-2.0)
        QEMU_MACHINE="${QEMU_MACHINE:-type=pc}"
        QEMU_RAM="${QEMU_RAM:-64M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-8G}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-tulip}"
        QEMU_EXTRA="${QEMU_EXTRA:--vga cirrus}"
        ;;
    linux-2.2)
        QEMU_MACHINE="${QEMU_MACHINE:-type=pc}"
        QEMU_RAM="${QEMU_RAM:-64M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-8G}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-tulip}"
        QEMU_EXTRA="${QEMU_EXTRA:--vga cirrus}"
        ;;
    linux-2.4)
        QEMU_MACHINE="${QEMU_MACHINE:-type=pc}"
        QEMU_RAM="${QEMU_RAM:-128M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-8G}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-tulip}"
        QEMU_EXTRA="${QEMU_EXTRA:--vga std}"
        ;;
    *)
        echo "Unknown QEMU_PROFILE '$QEMU_PROFILE'"
        exit 1
        ;;
    esac
}

# Assigns or validates one host port.
qemu_assign_port() {
    local label base current
    label=$1
    base=$2
    current=$3

    if [[ "$current" == "none" ]]; then
        return 0
    fi
    qemu_require_lsof || return 1
    if [[ -n "$current" ]]; then
        if qemu_port_listening "$current"; then
            echo "Requested $label port $current is already in use." >&2
            return 1
        fi
        printf '%s\n' "$current"
        return 0
    fi
    qemu_find_available_port "$label" "$base"
}

# Assigns all monitor and guest forwarding ports.
# Note: ports are scanned for availability and then handed to QEMU, so two
# concurrent launches could theoretically pick the same free port before either
# binds it. This is unlikely in practice; if a bind fails, just relaunch or set
# explicit QEMU_*_PORT values.
qemu_assign_ports() {
    if [[ "$QEMU_NET_TYPE" == "user" ]]; then
        QEMU_SSH_PORT=$(qemu_assign_port ssh "$QEMU_SSH_BASE" "$QEMU_SSH_PORT") || return 1
        QEMU_TELNET_PORT=$(qemu_assign_port telnet "$QEMU_TELNET_BASE" "$QEMU_TELNET_PORT") || return 1
        QEMU_HTTP_PORT=$(qemu_assign_port http "$QEMU_HTTP_BASE" "$QEMU_HTTP_PORT") || return 1
    fi
    QEMU_MONITOR_PORT=$(qemu_assign_port monitor "$QEMU_MONITOR_BASE" "$QEMU_MONITOR_PORT") || return 1
}

# Finalizes display, install script, and network configuration.
qemu_finish_config() {
    local qemu_internet_netdev
    local install_script

    QEMU_DISPLAY="${QEMU_DISPLAY:-$(qemu_default_display)}"
    QEMU_ACCEL="${QEMU_ACCEL:--accel tcg}"
    QEMU_EXTRA="${QEMU_EXTRA:-}"
    if [[ $COMMAND == "install" ]]; then
        if [[ -z "${QEMU_INSTALL_SCRIPT:-}" ]] && install_script=$(retro_config_file script.sh); then
            QEMU_INSTALL_SCRIPT="$install_script"
        fi
    fi
    # Validate QEMU_NET_TYPE
    case "$QEMU_NET_TYPE" in
    user | jump | none)
        ;;
    *)
        echo "Invalid QEMU_NET_TYPE '$QEMU_NET_TYPE'. Valid values: user, jump, none" >&2
        exit 1
        ;;
    esac

    # Configure network based on QEMU_NET_TYPE (unless explicitly overridden)
    if [[ -z "${QEMU_INTERNET:-}" && -z "${QEMU_RETRONET:-}" && -n "${QEMU_NET_DEVICE:-}" ]]; then
        case "$QEMU_NET_TYPE" in
        user)
            # User networking with port forwards (default behavior)
            qemu_internet_netdev="user,id=internet"
            if [[ -n "${QEMU_SSH_PORT:-}" && "$QEMU_SSH_PORT" != "none" ]]; then
                qemu_internet_netdev+=",hostfwd=tcp:127.0.0.1:$QEMU_SSH_PORT-:22"
            fi
            if [[ -n "${QEMU_TELNET_PORT:-}" && "$QEMU_TELNET_PORT" != "none" ]]; then
                qemu_internet_netdev+=",hostfwd=tcp:127.0.0.1:$QEMU_TELNET_PORT-:23"
            fi
            if [[ -n "${QEMU_HTTP_PORT:-}" && "$QEMU_HTTP_PORT" != "none" ]]; then
                qemu_internet_netdev+=",hostfwd=tcp:127.0.0.1:$QEMU_HTTP_PORT-:80"
            fi
            QEMU_INTERNET="
          -netdev $qemu_internet_netdev
          -device $QEMU_NET_DEVICE,netdev=internet"
            ;;
        jump)
            # Socket connection to jumpbox
            QEMU_RETRONET="
          -netdev socket,id=jumpnet,connect=:1234
          -device $QEMU_NET_DEVICE,netdev=jumpnet"
            ;;
        none)
            # No networking
            ;;
        esac
    fi
}

# Runs QEMU while a QMP-driven install script controls it.
qemu_run_with_install_script() {
    local qemu_pid script_status qemu_status
    qemu_status=0

    "${QEMU_ARGS[@]}" &
    qemu_pid=$!
    # shellcheck disable=SC2034 # Read by sourced install script helpers.
    QEMU_PID=$qemu_pid

    if ! qmp_init; then
        kill "$qemu_pid" 2>/dev/null || true
        wait "$qemu_pid" 2>/dev/null || true
        return 1
    fi

    (
        # shellcheck source=/dev/null
        source "$QEMU_INSTALL_SCRIPT"
    )
    script_status=$?
    if [[ $script_status -ne 0 ]]; then
        # Leave QEMU running on any install failure so the guest can be
        # inspected; the user exits QEMU manually when done investigating.
        if qmp_qemu_running; then
            echo "Install script failed (status $script_status)." >&2
            echo "QEMU has been left running so you can investigate the guest." >&2
            echo "Close the QEMU window (or use the monitor) to exit." >&2
        fi
        wait "$qemu_pid" 2>/dev/null || true
        return "$script_status"
    fi

    wait "$qemu_pid" || qemu_status=$?
    return "$qemu_status"
}

# Loads QEMU defaults, distro overrides, profile settings, and ports.
load_qemu_config() {
    local qemu_profile_env_decl qemu_profile_env=
    local qemu_profile_env_set=
    local qemu_config
    qemu_profile_env_decl=$(declare -p QEMU_PROFILE 2>/dev/null || true)
    if [[ $qemu_profile_env_decl == declare\ -*x* ]]; then
        qemu_profile_env=$QEMU_PROFILE
        qemu_profile_env_set=1
    fi

    qemu_base_defaults
    if qemu_config=$(retro_config_file qemu.sh); then
        # shellcheck source=/dev/null
        source "$qemu_config"
    fi
    if [[ -n "$qemu_profile_env_set" ]]; then
        QEMU_PROFILE=$qemu_profile_env
    fi
    qemu_apply_profile
    qemu_assign_ports || exit 1
    qemu_finish_config
}

# Loads optional distro-wide configuration.
load_distro_config() {
    local distro_config
    if distro_config=$(retro_config_file config.sh); then
        # shellcheck source=/dev/null
        source "$distro_config"
    fi
}

# Selects install-time media overrides and boot order.
qemu_select_command_media() {
    QEMU_FDA_OVERRIDE=
    QEMU_HDC_OVERRIDE=

    if [[ ($COMMAND == "install" || $COMMAND == "boot") && -f boot.img ]]; then
        QEMU_FDA_OVERRIDE=boot.img
    fi

    if [[ ($COMMAND == "install" || $COMMAND == "boot") && ! -f hdc.iso && -f install.iso ]]; then
        QEMU_HDC_OVERRIDE=install.iso
    fi

    if [[ $COMMAND != "install" ]]; then
        return
    fi

    if qemu_has_fda_media; then
        QEMU_BOOT_ORDER="-boot order=a"
    elif qemu_has_hdc_media; then
        QEMU_BOOT_ORDER="-boot order=d"
    fi
}

# Tests whether the first floppy has default or override media.
qemu_has_fda_media() {
    [[ -f fda.img || -n "${QEMU_FDA_OVERRIDE:-}" ]]
}

# Tests whether the CD-ROM has default or override media.
qemu_has_hdc_media() {
    [[ -f hdc.iso || -n "${QEMU_HDC_OVERRIDE:-}" ]]
}

# Tests whether any bootable startup media exists.
qemu_has_startup_media() {
    qemu_has_fda_media || qemu_has_hdc_media
}

# Creates the primary hard disk when startup media is available.
qemu_ensure_primary_disk() {
    local create_options
    if [[ ! -f hda.img ]]; then
        if qemu_has_startup_media; then
            create_options=()
            if [[ -n "${QEMU_HD_CREATE_OPTIONS:-}" ]]; then
                create_options=(-o "$QEMU_HD_CREATE_OPTIONS")
            fi
            qemu-img create -f "$QEMU_HD_FORMAT" "${create_options[@]}" hda.img "$QEMU_HD_SIZE"
        else
            return 1
        fi
    fi
}

# Maps drive names to QEMU interface indexes.
qemu_drive_index() {
    case "$1" in
    hda | fda) echo 0 ;;
    hdb | fdb) echo 1 ;;
    hdc) echo 2 ;;
    hdd) echo 3 ;;
    esac
}

# Adds one -drive argument to QEMU_DRIVES.
qemu_add_drive() {
    local interface=$1
    local index=$2
    local format=$3
    local options=$4

    QEMU_DRIVES+=(-drive "if=$interface,index=$index,format=$format,$options")
}

# Builds drive attachments from existing images, ISOs, and FAT directories.
qemu_build_drives() {
    local drive index interface format drive_options image_file iso_file
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

        index=$(qemu_drive_index "$drive")
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
            qemu_add_drive "$interface" "$index" "$format" "file=$image_file$drive_options"
        elif [[ -f $iso_file ]]; then
            qemu_add_drive "$interface" "$index" "$format" "media=cdrom,file=$iso_file"
        elif [[ $drive == "hdb" && -d fat ]]; then
            qemu_add_drive "$interface" "$index" raw "file=fat:rw:fat"
        elif [[ -d $drive ]]; then
            qemu_add_drive "$interface" "$index" raw "file=fat:rw:$drive"
        fi
    done
}

# Builds global floppy-controller options.
qemu_build_globals() {
    QEMU_GLOBALS=()
    if [[ -n "$QEMU_FDTYPE_A" ]]; then
        QEMU_GLOBALS+=(-global "isa-fdc.fdtypeA=$QEMU_FDTYPE_A")
    fi
    if [[ -n "$QEMU_FDTYPE_B" ]]; then
        QEMU_GLOBALS+=(-global "isa-fdc.fdtypeB=$QEMU_FDTYPE_B")
    fi
}

# Builds Unix socket chardev arguments for serial or parallel ports.
qemu_build_socket_chardevs() {
    local array_name=$1
    local option=$2
    local count=$3
    local prefix=$4
    local label=${5:-chardev}
    local i socket

    echo "Creating $count $label chardevs"
    eval "$array_name=()"
    for ((i = 0; i < count; i++)); do
        socket="$prefix$i.sock"
        rm -f "$socket"
        eval "$array_name+=( \"\$option\" \"unix:\$socket,server=on,wait=off\" )"
    done
}

# Builds guest serial socket arguments.
qemu_build_serials() {
    qemu_build_socket_chardevs QEMU_SERIALS -serial "$QEMU_SERIAL_SOCKET_COUNT" "$QEMU_SERIAL_SOCKET_PREFIX" serial
}

# Builds guest parallel socket arguments.
qemu_build_parallels() {
    qemu_build_socket_chardevs QEMU_PARALLELS -parallel "$QEMU_PARALLEL_SOCKET_COUNT" "$QEMU_PARALLEL_SOCKET_PREFIX" parallel
}

# Assembles the final QEMU argument array.
qemu_build_args() {
    QEMU_ARGS=(
        "$QEMU_SYSTEM"
        -machine "$QEMU_MACHINE"
        -smp "$QEMU_SMP"
        -m "$QEMU_RAM"
    )
    if [[ -n "${QEMU_QMP_SOCKET:-}" && "$QEMU_QMP_SOCKET" != "none" ]]; then
        QEMU_ARGS+=(-qmp "unix:$QEMU_QMP_SOCKET,server=on,wait=off")
    fi
    if [[ -n "${QEMU_MONITOR_PORT:-}" && "$QEMU_MONITOR_PORT" != "none" ]]; then
        QEMU_ARGS+=(-monitor "telnet:127.0.0.1:$QEMU_MONITOR_PORT,server=on,wait=off")
    fi
    QEMU_ARGS+=("${QEMU_SERIALS[@]}")
    QEMU_ARGS+=("${QEMU_PARALLELS[@]}")
    qemu_append_args_string "${QEMU_DISPLAY:-}"
    qemu_append_args_string "${QEMU_ACCEL:-}"
    qemu_append_args_string "${QEMU_INTERNET:-}"
    qemu_append_args_string "${QEMU_RETRONET:-}"
    QEMU_ARGS+=("${QEMU_GLOBALS[@]}")
    QEMU_ARGS+=("${QEMU_DRIVES[@]}")
    qemu_append_args_string "${QEMU_BOOT_ORDER:-}"
    qemu_append_args_string "${QEMU_EXTRA:-}"
    QEMU_ARGS+=("$@")
    QEMU_COMMAND=$(qemu_render_command_sh)
}

# Prints assigned QEMU and guest TCP ports.
qemu_print_ports() {
    local qmp_socket_path

    echo "QEMU endpoints:"
    if [[ -n "${QEMU_MONITOR_PORT:-}" && "$QEMU_MONITOR_PORT" != "none" ]]; then
        echo "  Monitor: localhost:$QEMU_MONITOR_PORT"
    fi
    if [[ -n "${QEMU_QMP_SOCKET:-}" && "$QEMU_QMP_SOCKET" != "none" ]]; then
        case "$QEMU_QMP_SOCKET" in
        /*) qmp_socket_path=$QEMU_QMP_SOCKET ;;
        *) qmp_socket_path=$QEMUDIR/$QEMU_QMP_SOCKET ;;
        esac
        echo "  QMP:     $qmp_socket_path"
    fi
    echo
    echo "Guest ports:"
    if [[ -n "${QEMU_SSH_PORT:-}" && "$QEMU_SSH_PORT" != "none" ]]; then
        echo "  SSH:     localhost:$QEMU_SSH_PORT -> guest :22"
    fi
    if [[ -n "${QEMU_TELNET_PORT:-}" && "$QEMU_TELNET_PORT" != "none" ]]; then
        echo "  Telnet:  localhost:$QEMU_TELNET_PORT -> guest :23"
    fi
    if [[ -n "${QEMU_HTTP_PORT:-}" && "$QEMU_HTTP_PORT" != "none" ]]; then
        echo "  HTTP:    localhost:$QEMU_HTTP_PORT -> guest :80"
    fi
}

# Prints guest disk and character device attachments.
qemu_print_guest_devices() {
    qemu_print_guest_disks
    echo
    qemu_print_guest_chardevs
}

# Prints the guest disk attachments.
qemu_print_guest_disks() {
    local i option value
    echo "Guest disks:"
    if [[ ${#QEMU_DRIVES[@]} -eq 0 ]]; then
        echo "  none"
    else
        for ((i = 0; i < ${#QEMU_DRIVES[@]}; i += 2)); do
            option=${QEMU_DRIVES[$i]}
            value=${QEMU_DRIVES[$((i + 1))]:-}
            echo "  $option $value"
        done
    fi
}

# Prints exported guest character devices.
qemu_print_guest_chardevs() {
    local printed_chardev=0

    echo "Guest character devices:"
    qemu_print_guest_chardev_args "${QEMU_SERIALS[@]}" && printed_chardev=1
    qemu_print_guest_chardev_args "${QEMU_PARALLELS[@]}" && printed_chardev=1
    if [[ $printed_chardev -eq 0 ]]; then
        echo "  none"
    fi
}

# Prints chardev arguments that expose Unix sockets or pipes.
qemu_print_guest_chardev_args() {
    local option printed=1 value

    while [[ $# -ge 2 ]]; do
        option=$1
        value=${2:-}
        case "$value" in
        unix:* | pipe:*)
            echo "  $option $value"
            printed=0
            ;;
        esac
        shift 2
    done
    return "$printed"
}

# Removes an empty qemu.d directory left by failed preparation.
qemu_cleanup_empty_dir() {
    if [[ -d $QEMUDIR && -z $(ls -A "$QEMUDIR") ]]; then
        rmdir "$QEMUDIR"
    fi
}

# Extracts files, loads config, and assembles the QEMU command without launching
# QEMU. Self-contained: enters and leaves $QEMUDIR balanced. Leaves the prepared
# command in QEMU_ARGS/QEMU_COMMAND for the caller to run or package.
retro_prepare() {
    retro_extract
    mkdir -p "$QEMUDIR"

    load_distro_config
    load_qemu_config

    pushd "$QEMUDIR" >/dev/null || return 1

    qemu_select_command_media
    if ! qemu_ensure_primary_disk; then
        echo "No bootable devices"
        popd >/dev/null || true
        qemu_cleanup_empty_dir
        exit 1
    fi

    qemu_build_drives
    qemu_build_globals
    qemu_build_serials
    qemu_build_parallels
    qemu_warn_missing_display_backend

    qemu_build_args "$@"

    echo
    qemu_print_ports
    echo
    qemu_print_guest_devices
    echo
    echo "QEMU command: $QEMU_COMMAND"
    echo
    popd >/dev/null || true
}

# Top-level retro command handler for booting or installing a distro.
retro_boot() {
    local run_status
    run_status=0

    retro_prepare "$@"

    pushd "$QEMUDIR" >/dev/null || return
    if [[ $COMMAND == "install" && -n "${QEMU_INSTALL_SCRIPT:-}" ]]; then
        qemu_run_with_install_script || run_status=$?
    elif [[ $COMMAND == "boot" || $COMMAND == "install" ]]; then
        "${QEMU_ARGS[@]}" || run_status=$?
    fi
    popd >/dev/null || return
    return "$run_status"
}

# Packages prepared QEMU files with runnable host scripts.
retro_package() {
    local files tarname package_root package_dir item
    if [[ $# -ge 1 && $1 == "--hda" ]]; then
        files=(hda.img retro.bat retro.sh)
        shift
    else
        files=()
    fi
    # Prepare images and the rendered command only; never boot QEMU to package.
    retro_prepare "$@"
    echo
    echo "Packaging $CONFNAME..."
    {
        printf '@echo off\n'
        qemu_render_command_cmd
    } >"$QEMUDIR/retro.bat"
    {
        printf '#!/bin/sh\n'
        printf '%s\n' "$QEMU_COMMAND"
    } >"$QEMUDIR/retro.sh"
    chmod +x "$QEMUDIR/retro.sh"
    tarname=$(printf '%s\n' "$CONFNAME" | tr / -)
    package_root=$TEMPDIR/package
    package_dir=$package_root/$tarname
    rm -rf "$package_root"
    mkdir -p "$package_dir"
    if [[ ${#files[@]} -eq 0 ]]; then
        for item in "$QEMUDIR"/*; do
            [[ -e "$item" ]] || continue
            cp -RL "$item" "$package_dir/"
        done
    else
        for item in "${files[@]}"; do
            [[ -e "$QEMUDIR/$item" ]] || continue
            cp -RL "$QEMUDIR/$item" "$package_dir/"
        done
    fi
    tar -C "$package_root" -czhf "$tarname.tar.gz" "$tarname"
    ls -lh "$tarname.tar.gz"
}

# Top-level retro command handler for deleting extracted QEMU files.
retro_reset() {
    read -p "Really remove QEMU images and extracted files for $CONFNAME? " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf "$EXTRACTDIR"
        rm -rf "$QEMUDIR"
        echo "Distro reset."
    else
        echo "Reset aborted."
    fi
}
