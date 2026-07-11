# shellcheck shell=bash
# QMP control-channel helpers.

# Sets default QMP connection settings.
qmp_set_defaults() {
    QEMU_QMP_SOCKET=${QEMU_QMP_SOCKET:-qmp.sock}
    QMP_TIMEOUT=${QMP_TIMEOUT:-1}
}

# Verifies commands required by the QMP control channel.
qmp_check_prereqs() {
    log_debug "Checking QMP helper prerequisites"
    if ! command -v nc >/dev/null 2>&1; then
        log_error "Missing nc in PATH"
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        log_error "Missing jq in PATH"
        return 1
    fi

    qmp_require_socket
}

# Resolves the configured QMP socket name to a client-side path.
qmp_socket_candidate() {
    case "$QEMU_QMP_SOCKET" in
    /* | none) printf '%s\n' "$QEMU_QMP_SOCKET" ;;
    *)
        if [[ "$QEMU_QMP_SOCKET" == */* ]]; then
            printf '%s\n' "$QEMU_QMP_SOCKET"
        elif [ -d qemu.d ]; then
            printf 'qemu.d/%s\n' "$QEMU_QMP_SOCKET"
        else
            printf '%s\n' "$QEMU_QMP_SOCKET"
        fi
        ;;
    esac
}

# Tests whether the current directory is the default QEMU work directory.
qmp_in_default_socket_dir() {
    [[ ${PWD##*/} == qemu.d || (-n "${QEMU_D:-}" && $PWD == "$QEMU_D") ]]
}

# Resolves the configured QMP socket and rejects ambiguous default locations.
qmp_socket_path() {
    local socket

    socket=$(qmp_socket_candidate) || return 1
    if [ "$QEMU_QMP_SOCKET" = "qmp.sock" ] && [ ! -d qemu.d ] && ! qmp_in_default_socket_dir && [ ! -S "$socket" ]; then
        log_error "Could not identify QMP socket. Run qmp from a distro config directory with qemu.d/qmp.sock, from inside qemu.d, or pass -s SOCKET."
        return 1
    fi
    printf '%s\n' "$socket"
}

# Prints the directory QEMU uses for relative HMP file paths.
qmp_hmp_file_dir() {
    local socket

    socket=$(qmp_socket_path) || return 1
    dirname "$socket"
}

# Verifies the configured QMP socket is usable.
qmp_require_socket() {
    local socket

    if [ "$QEMU_QMP_SOCKET" = "none" ]; then
        log_error "QMP socket is disabled"
        return 1
    fi

    socket=$(qmp_socket_path) || return 1
    if [ ! -S "$socket" ] && [ "${QMP_TIMEOUT:-0}" != "0" ]; then
        log_debug "Waiting up to $QMP_TIMEOUT second(s) for QMP socket $socket"
        sleep "$QMP_TIMEOUT"
    fi
    if [ ! -S "$socket" ]; then
        log_error "QMP socket does not exist: $socket"
        return 1
    fi
}

# Initializes QMP defaults and prerequisites.
qmp_init() {
    log_info "Initializing QMP control channel"
    qmp_set_defaults
    qmp_check_prereqs
}

# Tests whether the QEMU process for this install is still running.
qmp_qemu_running() {
    local state

    [ -n "${QEMU_PID:-}" ] || return 0
    state=$(ps -p "$QEMU_PID" -o stat= 2>/dev/null) || return 1
    [[ $state != Z* ]]
}

# Sends a human monitor command through QMP and prints raw QMP responses.
qmp_hmp_command_raw() {
    local command request response response_status error_response socket
    command=${1:-}
    response_status=0

    if [ -z "$command" ]; then
        log_error "Missing QMP HMP command"
        return 1
    fi

    socket=$(qmp_socket_path) || return 1
    log_debug "Sending QMP HMP command: $command"

    request=$(jq -nc --arg command "$command" \
        '{execute:"human-monitor-command",arguments:{"command-line":$command}}') || return 1
    response=$(
        {
            printf '{"execute":"qmp_capabilities"}\n'
            printf '%s\n' "$request"
        } | nc -U -w "$QMP_TIMEOUT" "$socket"
    ) || response_status=$?

    if [ -n "$response" ]; then
        error_response=$(printf '%s\n' "$response" |
            jq -c 'select(type == "object" and has("error"))' 2>/dev/null) || {
            log_error "Invalid QMP response for command: $command"
            printf '%s\n' "$response" >&2
            return 65
        }
        if [ -n "$error_response" ]; then
            printf '%s\n' "$error_response" >&2
            return 64
        fi
    fi

    if [ -z "$response" ] && [ "$response_status" -ne 0 ]; then
        return "$response_status"
    fi

    printf '%s\n' "$response"
}

# Tests whether QMP responses include a successful HMP command return.
qmp_hmp_response_has_hmp_return() {
    local return_count

    # One return is qmp_capabilities; the second is human-monitor-command.
    return_count=$(jq -s '[.[] | select(type == "object" and has("return"))] | length') || return 1
    [ "$return_count" -ge 2 ]
}

# Sends a human monitor command through QMP and requires an HMP success response.
qmp_hmp_command() {
    local response
    local status

    response=$(qmp_hmp_command_raw "$1") || {
        status=$?
        if [ "$status" -eq 64 ] || [ "$status" -eq 65 ]; then
            return 1
        fi
        log_error "QMP command failed with status $status: $1"
        return "$status"
    }
    if printf '%s\n' "$response" | qmp_hmp_response_has_hmp_return; then
        return 0
    fi

    log_error "QMP command returned no success response: $1"
    if [ -n "$response" ]; then
        printf '%s\n' "$response" >&2
    fi
    return 1
}
