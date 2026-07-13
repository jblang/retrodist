# shellcheck shell=bash
# QEMU host ports, user networking, forwarding, and endpoint reporting.

# Tests whether a TCP port already has a listener.
network_port_is_listening() {
    local port
    port=$1
    lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

# Verifies that lsof is available for port allocation.
network_require_lsof() {
    if ! command -v lsof >/dev/null 2>&1; then
        log_error "Missing lsof in PATH; cannot allocate QEMU ports."
        return 1
    fi
}

# Finds the first available port in a 100-port range.
network_find_available_port() {
    local base label offset port
    label=$1
    base=$2
    for ((offset = 0; offset <= 99; offset++)); do
        port=$((base + offset))
        if ! network_port_is_listening "$port"; then
            printf '%s\n' "$port"
            return 0
        fi
    done
    log_error "No available $label port found from $base through $((base + 99))."
    return 1
}

# Assigns or validates one host port.
network_assign_port() {
    local label base current
    label=$1
    base=$2
    current=$3

    if [[ "$current" == "none" ]]; then
        log_debug "Skipping $label port allocation"
        return 0
    fi
    network_require_lsof || return 1
    if [[ -n "$current" ]]; then
        if network_port_is_listening "$current"; then
            log_error "Requested $label port $current is already in use."
            return 1
        fi
        log_debug "Using requested $label port $current"
        printf '%s\n' "$current"
        return 0
    fi
    network_find_available_port "$label" "$base"
}

# Assigns all monitor and guest forwarding ports.
network_assign_ports() {
    log_debug "Assigning host ports"
    if network_is_enabled && [[ -z "${QEMU_NET_FORWARD:-}" ]]; then
        QEMU_SSH_PORT=$(network_assign_port ssh "$QEMU_SSH_BASE" "$QEMU_SSH_PORT") || return 1
        QEMU_TELNET_PORT=$(network_assign_port telnet "$QEMU_TELNET_BASE" "$QEMU_TELNET_PORT") || return 1
    fi
    QEMU_MONITOR_PORT=$(network_assign_port monitor "$QEMU_MONITOR_BASE" "$QEMU_MONITOR_PORT") || return 1
}

# Emits QEMU user-network forwarding options for QEMU_NET_FORWARD.
network_render_forward_suffix() {
    local forward forwards host_port guest_port extra result

    forwards=${QEMU_NET_FORWARD//,/ }
    case "$(printf '%s' "$forwards" | tr '[:upper:]' '[:lower:]')" in
    none | off | false | no | 0)
        return 0
        ;;
    esac

    result=
    for forward in $forwards; do
        IFS=: read -r host_port guest_port extra <<<"$forward"
        if [[ -z "$host_port" || -z "$guest_port" || -n "$extra" || ! "$host_port" =~ ^[0-9]+$ || ! "$guest_port" =~ ^[0-9]+$ ]]; then
            log_error "Invalid QEMU_NET_FORWARD pair '$forward'; use host:guest port pairs."
            return 1
        fi
        result+=",hostfwd=tcp:127.0.0.1:$host_port-:$guest_port"
    done
    printf '%s\n' "$result"
}

# Prints configured guest port forwards, prioritizing familiar services.
network_print_forwards() {
    local forward forwards host_port guest_port extra
    local indent=${QEMU_HARDWARE_DETAIL_INDENT:-    }

    forwards=${QEMU_NET_FORWARD//,/ }
    case "$(printf '%s' "$forwards" | tr '[:upper:]' '[:lower:]')" in
    none | off | false | no | 0)
        return 0
        ;;
    esac

    for forward in $forwards; do
        IFS=: read -r host_port guest_port extra <<<"$forward"
        case $guest_port in
        22)
            echo "${indent}SSH:     localhost:$host_port -> guest :$guest_port"
            ;;
        esac
    done
    for forward in $forwards; do
        IFS=: read -r host_port guest_port extra <<<"$forward"
        case $guest_port in
        23)
            echo "${indent}Telnet:  localhost:$host_port -> guest :$guest_port"
            ;;
        esac
    done
    for forward in $forwards; do
        IFS=: read -r host_port guest_port extra <<<"$forward"
        case $guest_port in
        22 | 23)
            ;;
        *)
            echo "${indent}TCP:     localhost:$host_port -> guest :$guest_port"
            ;;
        esac
    done
}

# Returns success unless QEMU_NET_ENABLED is a recognized false value.
network_is_enabled() {
    case "$(printf '%s' "$QEMU_NET_ENABLED" | tr '[:upper:]' '[:lower:]')" in
    0 | false | no | off | disable | disabled | none | n | f | null | nil)
        return 1
        ;;
    *)
        return 0
        ;;
    esac
}

# Prints assigned QEMU and guest TCP ports.
network_print_endpoints() {
    local guest_ports
    local indent=${QEMU_HARDWARE_DETAIL_INDENT:-    }

    echo "⚙️  QEMU endpoints:"
    if [[ -n "${QEMU_MONITOR_PORT:-}" && "$QEMU_MONITOR_PORT" != "none" ]]; then
        echo "${indent}Monitor: localhost:$QEMU_MONITOR_PORT"
    fi
    if [[ -n "${QEMU_QMP_PIPE:-}" && "$QEMU_QMP_PIPE" != "none" ]]; then
        echo "${indent}QMP:     $QEMU_QMP_PIPE.in / $QEMU_QMP_PIPE.out"
    fi
    guest_ports=$(network_print_forwards)
    if [[ -n "$guest_ports" ]]; then
        echo
        echo "📡 Guest ports:"
        printf '%s\n' "$guest_ports"
    fi
}

# Finalizes user networking and guest port forwarding.
network_build() {
    local default_forwards qemu_internet_netdev

    if ! network_is_enabled; then
        QEMU_NETWORK=()
        log_debug "Networking disabled by QEMU_NET_ENABLED=$QEMU_NET_ENABLED"
    elif [[ ${#QEMU_NETWORK[@]} -eq 0 && -n "${QEMU_NET_DEVICE:-}" ]]; then
        log_debug "Configuring user networking"
        qemu_internet_netdev="user,id=internet"
        if [[ -z "${QEMU_NET_FORWARD:-}" ]]; then
            default_forwards=
            if [[ -n "${QEMU_SSH_PORT:-}" && "$QEMU_SSH_PORT" != "none" ]]; then
                default_forwards="$QEMU_SSH_PORT:22"
            fi
            if [[ -n "${QEMU_TELNET_PORT:-}" && "$QEMU_TELNET_PORT" != "none" ]]; then
                default_forwards="${default_forwards:+$default_forwards }$QEMU_TELNET_PORT:23"
            fi
            QEMU_NET_FORWARD=$default_forwards
        fi
        qemu_internet_netdev+=$(network_render_forward_suffix) || return 1
        QEMU_NETWORK=(
            -netdev "$qemu_internet_netdev"
            -device "$QEMU_NET_DEVICE,netdev=internet"
        )
    elif [[ ${#QEMU_NETWORK[@]} -gt 0 ]]; then
        log_debug "Using explicit QEMU network configuration"
    else
        log_warn "No QEMU network device configured"
    fi
}
