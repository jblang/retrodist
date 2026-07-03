# shellcheck shell=bash
# QMP helpers for querying QEMU state.

# Sets default QMP connection and VGA dump settings.
qmp_set_defaults() {
    QEMU_QMP_SOCKET=${QEMU_QMP_SOCKET:-qmp.sock}
    QMP_TIMEOUT=${QMP_TIMEOUT:-1}

    VGA_ADDR=${VGA_ADDR:-0xb8000}
    VGA_COLS=${VGA_COLS:-80}
    VGA_ROWS=${VGA_ROWS:-25}
    VGA_MEM_BYTES=${VGA_MEM_BYTES:-32768}
}

# Verifies commands and decoder files required by the QMP helpers.
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

    if ! command -v xxd >/dev/null 2>&1; then
        log_error "Missing xxd in PATH"
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
    [[ ${PWD##*/} == qemu.d || (-n "${QEMUDIR:-}" && $PWD == "$QEMUDIR") ]]
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

# Initializes QMP defaults, prerequisites, and VGA settings.
qmp_init() {
    log_info "Initializing QMP control channel"
    qmp_set_defaults
    qmp_check_prereqs || return 1
    qmp_vga_validate_config
}

# Validates numeric VGA configuration used when decoding screen memory.
qmp_vga_validate_config() {
    case "$VGA_COLS:$VGA_ROWS:$VGA_MEM_BYTES" in
    *[!0-9:]* | :* | *:)
        log_error "VGA_COLS, VGA_ROWS, and VGA_MEM_BYTES must be positive integers"
        return 1
        ;;
    esac

    if [ "$VGA_COLS" -le 0 ] || [ "$VGA_ROWS" -le 0 ] || [ "$VGA_MEM_BYTES" -le 0 ]; then
        log_error "VGA_COLS, VGA_ROWS, and VGA_MEM_BYTES must be positive integers"
        return 1
    fi
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

# Ejects media from a QEMU block device.
qmp_eject_disk() {
    local device
    device=${1:-floppy0}

    echo "⏏️  Ejecting $device"
    qmp_hmp_command "eject $device"
}

# Changes the configured floppy device to the given image.
qmp_change_image() {
    local image device
    image=${1:-}
    device=${2:-floppy0}

    if [ -z "$image" ]; then
        log_error "Missing image for QMP change command"
        return 1
    fi
    qmp_hmp_command "change $device $image"
}

# Sets the QEMU boot device order.
qmp_boot_disk() {
    if [ -z "${1:-}" ]; then
        log_error "Missing boot device for QMP boot_set command"
        return 1
    fi
    echo "🎬 Set QEMU boot device to $1"
    qmp_hmp_command "boot_set $1"
}

# Dumps bytes from physical memory using QEMU pmemsave.
qmp_dump_physical_memory() {
    local addr bytes socket_dir dump_file qemu_dump_file response response_status
    addr=${1:-}
    bytes=${2:-}
    response_status=0

    if [ -z "$addr" ] || [ -z "$bytes" ]; then
        log_error "Missing address or byte count for QMP physical memory dump"
        return 1
    fi

    socket_dir=$(dirname "$(qmp_socket_path)") || return 1
    dump_file=$(mktemp "$socket_dir/retrodist-vga.XXXXXX") || return 1
    qemu_dump_file=$(basename "$dump_file")
    # QEMU pmemsave creates the file itself; keep mktemp's unique name only.
    rm -f "$dump_file"

    log_debug "Dumping QEMU physical memory at $addr for $bytes byte(s)"
    response=$(qmp_hmp_command_raw "pmemsave $addr $bytes $qemu_dump_file") || response_status=$?

    if [ ! -s "$dump_file" ]; then
        log_error "QMP pmemsave did not create screen dump: $dump_file"
        if [ "$response_status" -ne 0 ]; then
            log_error "QMP pmemsave command exited with status $response_status"
        fi
        if [ -n "$response" ]; then
            printf '%s\n' "$response" >&2
        fi
        rm -f "$dump_file"
        return 1
    fi

    if ! cat "$dump_file"; then
        rm -f "$dump_file"
        return 1
    fi
    rm -f "$dump_file"
}

# Sends a QEMU sendkey key sequence.
qmp_sendkey() {
    if [ -z "${1:-}" ]; then
        log_error "Missing key for QMP sendkey command"
        return 1
    fi
    log_debug "Sending QEMU key sequence $1"
    qmp_hmp_command "sendkey $1"
}

# Converts one character to a QEMU sendkey token.
qmp_char_to_sendkey() {
    case "$1" in
    [a-z] | [0-9]) printf '%s' "$1" ;;
    [A-Z]) printf 'shift-%s' "$1" | tr '[:upper:]' '[:lower:]' ;;
    $'\t') printf 'tab' ;;
    $'\n') printf 'ret' ;;
    $'\\') printf 'backslash' ;;
    ' ') printf 'spc' ;;
    '!') printf 'shift-1' ;;
    '@') printf 'shift-2' ;;
    '#') printf 'shift-3' ;;
    '$') printf 'shift-4' ;;
    '%') printf 'shift-5' ;;
    '^') printf 'shift-6' ;;
    '&') printf 'shift-7' ;;
    '*') printf 'shift-8' ;;
    '(') printf 'shift-9' ;;
    ')') printf 'shift-0' ;;
    '-') printf 'minus' ;;
    '_') printf 'shift-minus' ;;
    '=') printf 'equal' ;;
    '+') printf 'shift-equal' ;;
    '[') printf 'bracket_left' ;;
    '{') printf 'shift-bracket_left' ;;
    ']') printf 'bracket_right' ;;
    '}') printf 'shift-bracket_right' ;;
    '|') printf 'shift-backslash' ;;
    ';') printf 'semicolon' ;;
    ':') printf 'shift-semicolon' ;;
    "'") printf 'apostrophe' ;;
    '"') printf 'shift-apostrophe' ;;
    '`') printf 'grave_accent' ;;
    '~') printf 'shift-grave_accent' ;;
    ',') printf 'comma' ;;
    '<') printf 'shift-comma' ;;
    '.') printf 'dot' ;;
    '>') printf 'shift-dot' ;;
    '/') printf 'slash' ;;
    '?') printf 'shift-slash' ;;
    *) return 1 ;;
    esac
    return 0
}

# Types a string into the guest using QEMU sendkey.
qmp_send_string() {
    local text i char key
    text=${1:-}

    for ((i = 0; i < ${#text}; i++)); do
        char=${text:i:1}
        key=$(qmp_char_to_sendkey "$char") || {
            log_error "$(printf 'Unsupported character for QMP sendkey: %q' "$char")"
            return 1
        }
        qmp_sendkey "$key"
    done
}

# Reads stdin and types it into the guest.
qmp_send_stdin() {
    local char key

    # Read one byte at a time so trailing newlines are preserved.
    while IFS= read -r -n 1 char; do
        if [ -z "$char" ]; then
            char=$'\n'
        fi
        key=$(qmp_char_to_sendkey "$char") || {
            log_error "$(printf 'Unsupported character for QMP sendkey: %q' "$char")"
            return 1
        }
        qmp_sendkey "$key"
    done
}

# Extracts plain VGA text bytes from a saved VGA memory dump stream.
qmp_vga_decode_dump() {
    xxd -p -c 2 |
        cut -c 1-2 |
        xxd -r -p |
        LC_ALL=C tr -c '[:print:]' ' ' |
        fold -w "$VGA_COLS"
}

# Dumps VGA memory and decodes it as text.
qmp_vga_dump_text() {
    (
        set -o pipefail
        qmp_dump_physical_memory "$VGA_ADDR" "$VGA_MEM_BYTES" | qmp_vga_decode_dump
    )
}
