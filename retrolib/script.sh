# shellcheck shell=bash
# Reusable QMP-driven install script building blocks.

# Mounts the staged FAT partition and starts the in-guest installer.
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SCRIPT_AUTOINST_COMMAND="mkdir /retro && mount -t msdos /dev/hdb1 /retro && sh /retro/autoinst"

# Finds the staged FAT partition and runs first-boot autoconf.
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SCRIPT_AUTOCONF_COMMAND='if [ ! -d /retro/autoinst.d ]; then mkdir -p /retro && mount -t msdos /dev/hdb1 /retro; fi; /retro/autoinst.d/autoconf.sh'

# Sources a helper relative to the active install script.
script_import() {
    local helper
    if [[ -z "${QEMU_INSTALL_SCRIPT:-}" ]]; then
        die "script_import requires QEMU_INSTALL_SCRIPT to be set"
    fi
    helper=$(dirname "$QEMU_INSTALL_SCRIPT")/$1
    # shellcheck source=/dev/null
    source "$helper" || die "Failed to import $helper"
}

# Tests whether text contains expected fixed text.
text_contains_string() {
    local screen text
    screen=$1
    text=$2

    grep -F -- "$text" <<<"$screen" >/dev/null
}

# Tests whether text contains a trimmed line equal to expected text.
text_contains_line() {
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

# Waits until VGA text memory contains expected screen text. By default, TEXT
# matches anywhere on screen; pass -l to match trimmed full lines.
screen_wait() {
    local expected matcher=text_contains_string screen interval

    if [ "${1:-}" = "-l" ]; then
        matcher=text_contains_line
        shift
    fi
    [ $# -gt 0 ] || die "screen_wait requires [-l] TEXT [TEXT ...]"

    interval=${WAIT_INTERVAL:-0.1}
    for expected in "$@"; do
        printf "⏳ %s" "$expected"
        while :; do
            if ! qmp_qemu_running; then
                die "QEMU exited while waiting for screen match: $expected"
            fi
            if screen=$(qmp_vga_dump_text); then
                if "$matcher" "$screen" "$expected"; then
                    printf "\r🖥️  %s\033[K\n" "$expected"
                    break
                fi
            fi
            sleep "$interval"
        done
    done
}

# Sends one QEMU sendkey token to the guest one or more times.
kb_press_key() {
    local key count times
    key=$1
    count=${2:-1}

    case "$count" in
    *[!0-9]*)
        log_error "kb_press_key count must be a non-negative integer: $count"
        return 1
        ;;
    esac

	times=$([[ $count -gt 1 ]] && echo "($count times)")

	echo "👇 $key $times"

    while [ "$count" -gt 0 ]; do
        qmp_sendkey "$key" || return 1
        count=$((count - 1))
    done
}

# Sends a string followed by return with QMP keyboard input.
kb_send_line() {
	echo "⌨️  $1 ↩️"
	qmp_send_string "$1" || return 1
	qmp_sendkey ret || return 1
}

# Screen shell prompt; override when a guest uses another prompt.
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SHELL_PROMPT="#"

# Login prompt used by script_run_autoconf.
LOGIN_PROMPT="login:"

# Logs in after first boot and runs autoconf.
script_run_autoconf() {
    local password

    screen_wait -l "$LOGIN_PROMPT"
    kb_send_line root

    if [ "$#" -gt 0 ]; then
        password=$1
        screen_wait "Password:"
        kb_send_line "$password"
    else
        sleep 1
        kb_press_key ret
    fi

    screen_wait -l "$SHELL_PROMPT"
    kb_send_line "$SCRIPT_AUTOCONF_COMMAND"
}

# Swaps the first floppy image.
script_change_floppy() {
    echo "💾 Inserting '$1'"
    qmp_change_image "$1"
    sleep 1
}

# Set the next QEMU boot device.
script_set_boot() {
    qmp_boot_disk "$1"
}
