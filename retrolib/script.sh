# shellcheck shell=bash
# Reusable QMP-driven install script building blocks.

# Tests whether screen text contains expected fixed text.
script_screen_contains_text() {
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

    while :; do
        if ! qmp_qemu_running; then
            echo "QEMU exited while waiting for screen match: $expected" >&2
            exit 1
        fi

        if screen=$(qmp_vga_dump_text); then
            "$matcher" "$screen" "$expected" && return 0
        fi

        if [ "$timeout" != "0" ] && [ $((SECONDS - start)) -ge "$timeout" ]; then
            echo "Timed out waiting for screen match: '$expected'" >&2
            exit 124
        fi

        sleep "$interval"
    done
}

# Waits until VGA text memory contains expected screen text anywhere.
script_wait_screen_text() {
    script_wait_until script_screen_contains_text "$1" "${2:-${WAIT_TIMEOUT:-60}}" "${3:-${WAIT_INTERVAL:-1}}"
}

# Waits until VGA text memory contains expected text on a line by itself.
script_wait_screen_line() {
    script_wait_until script_screen_contains_line "$1" "${2:-${WAIT_TIMEOUT:-60}}" "${3:-${WAIT_INTERVAL:-1}}"
}

# Waits for a LILO prompt and presses Return.
script_boot_lilo() {
    script_wait_screen_line "${1:-boot:}"
    qmp_send_return
}

# Waits for a prompt and sends an optional answer.
script_answer_prompt() {
    local prompt answer
    prompt=$1
    answer=${2:-}
    script_wait_screen_line "$prompt"
    if [[ -n "$answer" ]]; then
        qmp_send_line "$answer"
    else
        qmp_send_return
    fi
}

# Swaps the first floppy image while answering an installer prompt.
script_change_floppy() {
    local prompt image answer
    prompt=$1
    image=${2:-root.img}
    answer=${3:-}

    script_wait_screen_line "$prompt"
    qmp_change_image "$image"
    sleep 1
    if [[ -n "$answer" ]]; then
        qmp_send_string "$answer"
    fi
    qmp_send_return
}

# Sends one QEMU sendkey token to the guest.
script_press_key() {
    qmp_sendkey "$1"
}

# Sends Return to the guest.
script_send_return() {
    qmp_send_return
}

# Waits for a login prompt and enters a username.
script_login() {
    local prompt user
    prompt=$1
    user=${2:-root}

    script_wait_screen_line "$prompt"
    qmp_send_line "$user"
}

# Mounts the staged FAT media and launches the autoinstall script.
script_run_autoinst() {
    local prompt
    prompt=$1

    script_wait_screen_line "$prompt"
    qmp_send_line "mkdir /retro && mount -t msdos /dev/hdb1 /retro && sh /retro/autoinst"
}

# Sets the next boot device and confirms the final reboot prompt.
script_finish_reboot() {
    local disk prompt timeout
    disk="${1:-c}"
    prompt="${2:-ATTN: Press ENTER to reboot.}"
    timeout="${3:-600}"
    script_wait_screen_line "$prompt" "$timeout"
    qmp_boot_disk "$disk"
    qmp_send_return
}
