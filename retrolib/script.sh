# shellcheck shell=bash
# Reusable QMP-driven install script building blocks.

# command to mount fat partition and run autoinst
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SCRIPT_AUTOINST_COMMAND="mkdir /retro && mount -t msdos /dev/hdb1 /retro && sh /retro/autoinst"

# Tests whether screen text contains expected fixed text.
script_screen_contains_string() {
    local screen text
    screen=$1
    text=$2

    grep -F -- "$text" <<<"$screen" >/dev/null
}

# Tests whether screen text contains a line whose trimmed content is expected text.
script_screen_contains_line() {
    local screen expected line trimmed_expected
    screen=$1
    expected=$2
    trimmed_expected=$expected
    trimmed_expected=${trimmed_expected#"${trimmed_expected%%[![:space:]]*}"}
    trimmed_expected=${trimmed_expected%"${trimmed_expected##*[![:space:]]}"}

    while IFS= read -r line; do
        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}
        [ "$line" = "$trimmed_expected" ] && return 0
    done <<<"$screen"

    return 1
}

# Waits until VGA text memory satisfies the given matcher function.
script_wait_until() {
    local expected matcher timeout interval start screen
    matcher=$1
    expected=$2
    timeout=${3:-${WAIT_TIMEOUT:-60}}
    interval=${4:-${WAIT_INTERVAL:-1}}
    start=$SECONDS

    log_info "Waiting for guest screen: $expected"
    while :; do
        if ! qmp_qemu_running; then
            die "QEMU exited while waiting for screen match: $expected"
        fi

        if screen=$(qmp_vga_dump_text); then
            if "$matcher" "$screen" "$expected"; then
                log_info "Guest screen matched: $expected"
                return 0
            fi
        else
            log_debug "Unable to read guest screen while waiting for: $expected"
        fi

        if [ "$timeout" != "0" ] && [ $((SECONDS - start)) -ge "$timeout" ]; then
            log_error "Timed out waiting for screen match: '$expected'"
            exit 124
        fi

        sleep "$interval"
    done
}

# Waits until VGA text memory contains expected screen text anywhere.
script_wait_string() {
    script_wait_until script_screen_contains_string "$1" "${2:-${WAIT_TIMEOUT:-60}}" "${3:-${WAIT_INTERVAL:-1}}"
}

# Waits until VGA text memory contains expected text on a line by itself.
script_wait_line() {
    script_wait_until script_screen_contains_line "$1" "${2:-${WAIT_TIMEOUT:-60}}" "${3:-${WAIT_INTERVAL:-1}}"
}

# Sends one QEMU sendkey token to the guest.
script_press_key() {
    qmp_sendkey "$1"
}

# Sends a string followed by return
script_send_line() {
	qmp_send_string "$1"
	qmp_sendkey ret
}

# Swaps the first floppy image.
script_change_floppy() {
    qmp_change_image "$1"
    sleep 1
}

script_set_boot() {
    qmp_boot_disk "$1"
}
