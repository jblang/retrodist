# shellcheck shell=bash
# QEMU defaults, profiles, distro overrides, and display configuration.

# Finds a distro config file in the selected directory or its parent.
config_find_file() {
    local dir name path parent
    if [[ $# -eq 1 ]]; then
        dir=$DISTRO_D
        name=$1
    elif [[ $# -eq 2 ]]; then
        dir=$1
        name=$2
    else
        log_error "Usage: config_find_file [DIR] FILE"
        return 1
    fi

    path=$dir/$name
    if [[ -f "$path" ]]; then
        printf '%s\n' "$path"
        return 0
    fi

    parent=$(dirname "$dir")
    path=$parent/$name
    if [[ "$parent" != "$dir" && -f "$path" ]]; then
        printf '%s\n' "$path"
        return 0
    fi

    return 1
}

# Chooses the default QEMU display backend for the host OS.
config_default_display() {
    case "$(uname -s)" in
    Darwin)
        echo "cocoa"
        ;;
    *)
        echo "gtk"
        ;;
    esac
}

# Extracts the backend name from a QEMU_DISPLAY value.
config_display_backend() {
    local display=$1 backend
    if [[ -z "$display" ]]; then
        return 1
    fi

    backend=${display%%[ ,]*}
    backend=${backend%%=*}
    [[ -n "$backend" ]] || return 1
    printf '%s\n' "$backend"
}

# Prints the detected QEMU major version.
config_detect_qemu_major() {
    local version_line version
    version_line=$("$QEMU_SYSTEM" --version 2>/dev/null | sed -n '1p' || true)
    version=${version_line#* version }
    case "$version" in
    [0-9]*)
        printf '%s\n' "${version%%.*}"
        return 0
        ;;
    esac
    return 1
}

# Enables Cocoa zoom/scaling options only where QEMU supports them.
config_apply_display_scaling() {
    local backend qemu_major
    backend=$(config_display_backend "$QEMU_DISPLAY" || true)
    if [[ "$backend" != "cocoa" ]]; then
        return
    fi
    qemu_major=$(config_detect_qemu_major || true)
    if [[ "$qemu_major" == "11" ]]; then
        QEMU_DISPLAY="$QEMU_DISPLAY,zoom-to-fit=on,zoom-interpolation=on"
    fi
}

# Warns when the configured QEMU display backend is unavailable.
config_warn_if_display_unavailable() {
    local backend available
    backend=$(config_display_backend "$QEMU_DISPLAY" || true)
    if [[ -z "$backend" || "$backend" == "none" ]]; then
        return
    fi

    available=$($QEMU_SYSTEM -display help 2>/dev/null || true)
    if [[ -n "$available" && "$available" != *"$backend"* ]]; then
        log_warn "$QEMU_SYSTEM does not have the '$backend' display backend installed."
        log_warn "Install a QEMU UI backend package, or set QEMU_DISPLAY to another backend."
    fi
}

# Sets baseline QEMU defaults before distro overrides are sourced.
config_set_defaults() {
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
    QEMU_VGA="${QEMU_VGA:-}"
    # shellcheck disable=SC2034 # Read by qemu-command.sh after config loading.
    QEMU_EXTRA=()

    # Network options
    QEMU_NET_ENABLED="${QEMU_NET_ENABLED:-true}"
    # shellcheck disable=SC2034 # Read by qemu-network.sh and qemu-command.sh.
    QEMU_NETWORK=()
    QEMU_NET_FORWARD="${QEMU_NET_FORWARD:-}"

    # Serial/parallel ports (chardev)
    QEMU_SERIAL_SOCKET_COUNT="${QEMU_SERIAL_SOCKET_COUNT:-2}"
    QEMU_SERIAL_SOCKET_PREFIX="${QEMU_SERIAL_SOCKET_PREFIX:-ttyS}"
    # Third port, reserved so the scripting pipe always lands on the fourth.
    # Guests needing a serial mouse claim it with QEMU_SERIAL_AUX=msmouse.
    QEMU_SERIAL_AUX="${QEMU_SERIAL_AUX:-null}"
    QEMU_SERIAL_PIPE="${QEMU_SERIAL_PIPE:-ttyS3}"
    QEMU_PARALLEL_SOCKET_COUNT="${QEMU_PARALLEL_SOCKET_COUNT:-1}"
    QEMU_PARALLEL_SOCKET_PREFIX="${QEMU_PARALLEL_SOCKET_PREFIX:-lp}"

    # QEMU monitor port and QMP pipe
    QEMU_MONITOR_BASE="${QEMU_MONITOR_BASE:-5555}"
    QEMU_MONITOR_PORT="${QEMU_MONITOR_PORT:-}"
    QEMU_QMP_PIPE="${QEMU_QMP_PIPE:-qmp}"

    # Guest port forwards
    QEMU_SSH_BASE="${QEMU_SSH_BASE:-2200}"
    QEMU_SSH_PORT="${QEMU_SSH_PORT:-}"
    QEMU_TELNET_BASE="${QEMU_TELNET_BASE:-2300}"
    QEMU_TELNET_PORT="${QEMU_TELNET_PORT:-}"

    # Install scripting
    QEMU_INSTALL_SCRIPT="${QEMU_INSTALL_SCRIPT:-}"
}

# Applies hardware defaults for a named distro-era profile.
config_apply_profile() {
    QEMU_PROFILE=${1:-${QEMU_PROFILE:-default}}
    log_debug "Applying QEMU profile $QEMU_PROFILE"
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
        QEMU_ACCEL="${QEMU_ACCEL:-tcg}"
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
        QEMU_VGA="${QEMU_VGA:-cirrus}"
        ;;
    linux-2.2)
        QEMU_MACHINE="${QEMU_MACHINE:-type=pc}"
        QEMU_RAM="${QEMU_RAM:-64M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-8G}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-tulip}"
        QEMU_VGA="${QEMU_VGA:-cirrus}"
        ;;
    linux-2.4)
        QEMU_MACHINE="${QEMU_MACHINE:-type=pc}"
        QEMU_RAM="${QEMU_RAM:-128M}"
        QEMU_HD_SIZE="${QEMU_HD_SIZE:-8G}"
        QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-tulip}"
        QEMU_VGA="${QEMU_VGA:-std}"
        ;;
    *)
        die "Unknown QEMU_PROFILE '$QEMU_PROFILE'"
        ;;
    esac
}

# Finalizes display and acceleration configuration.
config_finalize_display() {
    QEMU_DISPLAY="${QEMU_DISPLAY:-$(config_default_display)}"
    config_apply_display_scaling
    QEMU_ACCEL="${QEMU_ACCEL:-tcg}"
    log_debug "Using QEMU display: $QEMU_DISPLAY"
    log_debug "Using QEMU acceleration: $QEMU_ACCEL"
    log_debug "Using QEMU VGA: ${QEMU_VGA:-(default)}"
}

# Selects the host-side install script when requested.
config_select_install_script() {
    local install_script

    if [[ $COMMAND != "install" ]]; then
        return
    fi
    if [[ -z "${QEMU_INSTALL_SCRIPT:-}" ]] && install_script=$(config_find_file install.sh); then
        QEMU_INSTALL_SCRIPT="$install_script"
        log_debug "Using install script $QEMU_INSTALL_SCRIPT"
    elif [[ -n "${QEMU_INSTALL_SCRIPT:-}" ]]; then
        log_debug "Using configured install script $QEMU_INSTALL_SCRIPT"
    else
        log_warn "Install command has no host-side install.sh configured"
    fi
}

# Loads QEMU defaults, distro overrides, profile settings, and ports.
config_load() {
    local qemu_profile_env_decl qemu_profile_env=
    local qemu_profile_env_set=
    local qemu_config
    qemu_profile_env_decl=$(declare -p QEMU_PROFILE 2>/dev/null || true)
    if [[ $qemu_profile_env_decl == declare\ -*x* ]]; then
        qemu_profile_env=$QEMU_PROFILE
        qemu_profile_env_set=1
    fi

    log_debug "Loading QEMU configuration"
    config_set_defaults
    if qemu_config=$(config_find_file qemu.sh); then
        log_debug "Sourcing QEMU config $qemu_config"
        # shellcheck source=/dev/null
        source "$qemu_config"
    else
        log_debug "No qemu.sh configured; using defaults"
    fi
    if [[ -n "$qemu_profile_env_set" ]]; then
        log_debug "Restoring QEMU_PROFILE from environment: $qemu_profile_env"
        QEMU_PROFILE=$qemu_profile_env
    fi
    config_apply_profile
    network_assign_ports || return 1
    config_finalize_display
    config_select_install_script
    network_build
}
