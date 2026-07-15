# shellcheck shell=bash
# QMP-backed VGA text memory helpers.

# Sets default VGA dump settings.
vga_set_defaults() {
    VGA_ADDR=${VGA_ADDR:-0xb8000}
    VGA_COLS=${VGA_COLS:-80}
    VGA_ROWS=${VGA_ROWS:-25}
    VGA_MEM_BYTES=${VGA_MEM_BYTES:-32768}
}

# Verifies commands required by VGA decoding.
vga_check_prereqs() {
    if ! command -v xxd >/dev/null 2>&1; then
        log_error "Missing xxd in PATH"
        return 1
    fi
}

# Validates numeric VGA configuration used when decoding screen memory.
vga_validate_config() {
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

# Dumps bytes from physical memory using QEMU pmemsave.
vga_read_physical_memory() {
    local addr bytes hmp_file_dir dump_file qemu_dump_file
    addr=${1:-}
    bytes=${2:-}

    if [ -z "$addr" ] || [ -z "$bytes" ]; then
        log_error "Missing address or byte count for QMP physical memory dump"
        return 1
    fi

    hmp_file_dir=$(qmp_hmp_file_dir) || return 1
    dump_file=$(mktemp "$hmp_file_dir/retrodist-vga.XXXXXX") || return 1
    qemu_dump_file=$(basename "$dump_file")
    # QEMU pmemsave creates the file itself; keep mktemp's unique name only.
    rm -f "$dump_file"

    log_debug "Dumping QEMU physical memory at $addr for $bytes byte(s)"
    if ! qmp_hmp_commands "pmemsave $addr $bytes $qemu_dump_file"; then
        rm -f "$dump_file"
        return 1
    fi

    if [ ! -s "$dump_file" ]; then
        log_error "QMP pmemsave did not create screen dump: $dump_file"
        rm -f "$dump_file"
        return 1
    fi

    if ! cat "$dump_file"; then
        rm -f "$dump_file"
        return 1
    fi
    rm -f "$dump_file"
}

# Extracts plain VGA text bytes from a saved VGA memory dump stream.
vga_decode_text_memory() {
    xxd -p -c 2 |
        cut -c 1-2 |
        xxd -r -p |
        LC_ALL=C tr -c '[:print:]' ' ' |
        fold -w "$VGA_COLS"
}

# Dumps VGA memory and decodes it as text.
vga_read_text() {
    vga_set_defaults
    vga_check_prereqs || return 1
    vga_validate_config || return 1
    (
        set -o pipefail
        vga_read_physical_memory "$VGA_ADDR" "$VGA_MEM_BYTES" | vga_decode_text_memory
    )
}

# Waits until VGA text memory contains expected screen text. By default, TEXT
# matches anywhere on screen; pass -l to match trimmed full lines, or -r to
# match each TEXT as an extended regex. Pass -t SECONDS to return 1 instead of
# waiting forever when text never appears.
vga_wait() {
    local expected matcher=text_contains_string screen interval
    local timeout='' remaining=''

    while [ $# -gt 0 ]; do
        case "$1" in
        -l)
            matcher=text_contains_line
            shift
            ;;
        -r)
            matcher=text_contains_regex
            shift
            ;;
        -t)
            [ $# -ge 2 ] || die "vga_wait -t requires SECONDS"
            timeout=$2
            shift 2
            ;;
        *)
            break
            ;;
        esac
    done
    [ $# -gt 0 ] || die "vga_wait requires [-l | -r] [-t SECONDS] TEXT [TEXT ...]"

    interval=${VGA_WAIT_INTERVAL:-${WAIT_INTERVAL:-0.25}}
    for expected in "$@"; do
        printf "⏳ %s" "$expected"
        if [ -n "$timeout" ]; then
            remaining=$(awk -v t="$timeout" -v i="$interval" 'BEGIN { printf "%d", t / i }')
        fi
        while :; do
            if ! qmp_vm_is_running; then
                die "QEMU exited while waiting for screen match: $expected"
            fi
            if screen=$(vga_read_text); then
                if "$matcher" "$screen" "$expected"; then
                    printf "\r🖥️  %s\033[K\n" "$expected"
                    break
                fi
            fi
            if [ -n "$remaining" ]; then
                if [ "$remaining" -le 0 ]; then
                    printf "\r⌛ %s\033[K\n" "$expected"
                    return 1
                fi
                remaining=$((remaining - 1))
            fi
            sleep "$interval"
        done
    done
}
