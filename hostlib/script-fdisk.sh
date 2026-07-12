# shellcheck shell=bash
# Host-side fdisk scripting helpers.
#
# These helpers create a two-partition guest disk before an installer begins:
# a swap partition of the requested size and a root partition using the
# remaining cylinders. They drive the guest's interactive `fdisk` through the
# serial console instead of assuming a particular fdisk version or disk size.
#
# Call `fdisk_swap_root DEVICE SWAP_MB` when the helper should open and exit a
# serial shell itself. Installers already in a serial shell call
# `fdisk_partitions SWAP_MB` instead. The latter consumes fdisk prompts,
# clears possible old partitions, creates both primary partitions, assigns
# Linux swap (82) and native Linux (83) types, prints the resulting table, and
# writes it.
#
# fdisk prompt ranges differ between releases, including optional brackets and
# default values. `fdisk_parse_range` extracts each advertised cylinder range,
# while `fdisk_wait_range` waits on the serial stream and stores it for the
# partitioning sequence. Failures are returned to the caller before the
# installer continues.

# Bare fdisk cylinder prompt range, handling bracketed/default variants.
INSTALL_FDISK_RANGE='\(\[?([0-9]+)\]?-\[?([0-9]+)\]?(, default [0-9]+)?\): *$'

# Extracts the first and last available cylinders from a bare fdisk prompt line.
fdisk_parse_range() {
    local line
    line=$1

    if [[ $line =~ $INSTALL_FDISK_RANGE ]]; then
        printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

# Stores the next fdisk cylinder range in INSTALL_FDISK_FIRST/LAST.
fdisk_wait_range() {
    local pattern line range

    [ $# -eq 1 ] || die "fdisk_wait_range requires PATTERN"
    pattern=$1

    # A capturing subshell would lose the serial consumption offset.
    serial_wait_until text_contains_regex "$pattern" >/dev/null
    line=$SERIAL_MATCHED_TEXT

    range=$(fdisk_parse_range "$line") || {
        log_error "Unable to parse fdisk cylinder range: $line"
        return 1
    }
    read -r INSTALL_FDISK_FIRST INSTALL_FDISK_LAST <<<"$range"
}

# Announces partitioning on the physical console, then starts fdisk.
fdisk_start() {
    local device quoted_device command

    [ $# -eq 1 ] || die "fdisk_start requires DEVICE"
    device=$1
    quoted_device=$(qemu_command_quote_posix_word "$device")
    command="fdisk $quoted_device"
    if [ "$device" = /dev/hda ]; then
        command="[ -b $quoted_device ] || mknod $quoted_device b 3 0; $command"
    fi
    serial_console_divider || return 1
    serial_console_echo "Partitioning $device; this may take a while..." || return 1
    serial_shell_send --no-wait "$command"
}

# Creates swap and root partitions by driving fdisk through a serial shell.
fdisk_swap_root() {
    local device swap_mb status=0

    if [[ $# -ne 2 ]]; then
        log_error "Usage: fdisk_swap_root DEVICE SWAP_MB"
        return 1
    fi

    device=$1
    swap_mb=$2

    serial_shell_start || return 1
    fdisk_start "$device" || return 1
    fdisk_partitions "$swap_mb" || status=$?
    [[ $status -eq 0 ]] || return "$status"

    serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1
    serial_send "exit" || return 1

    # fdisk has exited; the serial shell's exit returns to the screen shell.
    vga_wait -l "$SHELL_PROMPT"
}

# Drives fdisk's interactive prompts over the serial pipe.
fdisk_partitions() {
    local swap_mb first_prompt last_prompt

    [ $# -eq 1 ] || die "fdisk_partitions requires SWAP_MB"

    swap_mb=$1
    first_prompt="First cylinder $INSTALL_FDISK_RANGE"
    last_prompt="Last cylinder .*$INSTALL_FDISK_RANGE"

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
    fdisk_wait_range "$first_prompt" || return 1
    serial_send "$INSTALL_FDISK_FIRST"
    fdisk_wait_range "$last_prompt" || return 1
    serial_send "+${swap_mb}M"

    # root partition filling the rest of the disk
    serial_prompt "Command (m for help):" "n"
    serial_send "p" # primary
    serial_prompt "Partition number (1-4):" "2"
    fdisk_wait_range "$first_prompt" || return 1
    serial_send "$INSTALL_FDISK_FIRST"
    fdisk_wait_range "$last_prompt" || return 1
    serial_send "$INSTALL_FDISK_LAST"

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
