# shellcheck shell=bash
# Host-side fdisk scripting helpers.

# Bare fdisk cylinder prompt range, handling bracketed/default variants.
SCRIPT_FDISK_RANGE='\(\[?([0-9]+)\]?-\[?([0-9]+)\]?(, default [0-9]+)?\): *$'

# Extracts the first and last available cylinders from a bare fdisk prompt line.
script_fdisk_parse_range() {
    local line
    line=$1

    if [[ $line =~ $SCRIPT_FDISK_RANGE ]]; then
        printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

# Stores the next fdisk cylinder range in SCRIPT_FDISK_FIRST/LAST.
script_fdisk_wait_range() {
    local pattern line range

    [ $# -eq 1 ] || die "script_fdisk_wait_range requires PATTERN"
    pattern=$1

    # A capturing subshell would lose the serial consumption offset.
    serial_wait_until serial_contains_regex "$pattern" >/dev/null
    line=$SERIAL_MATCHED_TEXT

    range=$(script_fdisk_parse_range "$line") || {
        log_error "Unable to parse fdisk cylinder range: $line"
        return 1
    }
    read -r SCRIPT_FDISK_FIRST SCRIPT_FDISK_LAST <<<"$range"
}

# Creates swap and root partitions by driving fdisk through a serial shell.
script_fdisk() {
    local device swap_mb status=0

    if [[ $# -ne 2 ]]; then
        log_error "Usage: script_fdisk DEVICE SWAP_MB"
        return 1
    fi

    device=$1
    swap_mb=$2

    serial_shell --no-wait "fdisk $device" || return 1
    script_fdisk_partitions "$swap_mb" || status=$?
    [[ $status -eq 0 ]] || return "$status"

    serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1
    serial_send "exit" || return 1

    # fdisk has exited; the serial shell's exit returns to the screen shell.
    screen_wait -l "$SHELL_PROMPT"
}

# Drives fdisk's interactive prompts over the serial pipe.
script_fdisk_partitions() {
    local swap_mb first_prompt last_prompt

    [ $# -eq 1 ] || die "script_fdisk_partitions requires SWAP_MB"

    swap_mb=$1
    first_prompt="First cylinder $SCRIPT_FDISK_RANGE"
    last_prompt="Last cylinder .*$SCRIPT_FDISK_RANGE"

    # Clear possible leftovers; fdisk silently skips already-empty slots.
    # Newer fdisk (9.0) refuses to prompt for a number on an empty disk.
    serial_prompt "Command (m for help):" "d"
    if serial_wait_alternative \
        "Partition number (1-4):" \
        "No partition is defined yet" >/dev/null; then
        serial_send "1"
        serial_prompt "Command (m for help):" "d"
        serial_prompt "Partition number (1-4):" "2"
    fi

    # swap partition, sized in MB
    serial_prompt "Command (m for help):" "n"
    serial_send "p" # primary; fdisk buffers this while printing the menu
    serial_prompt "Partition number (1-4):" "1"
    script_fdisk_wait_range "$first_prompt" || return 1
    serial_send "$SCRIPT_FDISK_FIRST"
    script_fdisk_wait_range "$last_prompt" || return 1
    serial_send "+${swap_mb}M"

    # root partition filling the rest of the disk
    serial_prompt "Command (m for help):" "n"
    serial_send "p" # primary
    serial_prompt "Partition number (1-4):" "2"
    script_fdisk_wait_range "$first_prompt" || return 1
    serial_send "$SCRIPT_FDISK_FIRST"
    script_fdisk_wait_range "$last_prompt" || return 1
    serial_send "$SCRIPT_FDISK_LAST"

    # partition types: Linux swap and Linux native
    serial_prompt "Command (m for help):" "t"
    serial_prompt "Partition number (1-4):" "1"
    serial_prompt "Hex code (type L to list codes):" "82"
    serial_prompt "Command (m for help):" "t"
    serial_prompt "Partition number (1-4):" "2"
    serial_prompt "Hex code (type L to list codes):" "83"

    # Print the final table for the transcript, then write it and exit.
    serial_prompt "Command (m for help):" "p"
    serial_prompt "Command (m for help):" "w"
}
