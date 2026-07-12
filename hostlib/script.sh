# shellcheck shell=bash
# Reusable QMP-driven install script building blocks.

# Mounts the staged FAT partition when needed and runs postinst.
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
INSTALL_POSTINST_COMMAND='if [ ! -d /retro/guestlib.d ]; then mkdir -p /retro && mount -t msdos /dev/hdb1 /retro; fi; /retro/guestlib.d/postinst.sh'

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

# Screen shell prompt; override when a guest uses another prompt.
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SHELL_PROMPT="#"

# Login prompt used by script_run_postinst.
LOGIN_PROMPT="login:"

# Logs in to the installed system and runs postinst.
script_run_postinst() {
    local password

    vga_wait -l "$LOGIN_PROMPT"
    kb_type -n root

    if [ "$#" -gt 0 ]; then
        password=$1
        vga_wait "Password:"
        kb_type -n "$password"
    else
        sleep 1
        kb_press ret
    fi

    vga_wait -l "$SHELL_PROMPT"
    kb_type -n "$INSTALL_POSTINST_COMMAND"
}

# Changes the configured media device to the given image.
script_change_image() {
    local image device format
    image=${1:-}
    device=${2:-floppy0}
    format=${3:-raw}

    if [ -z "$image" ]; then
        log_error "Missing image for QMP change command"
        return 1
    fi
    qmp_hmp_command "change $device $image $format"
}

# Ejects media from a QEMU block device.
script_eject_disk() {
    local device
    device=${1:-floppy0}

    echo "⏏️  Ejecting $device"
    qmp_hmp_command "eject $device"
}

# Swaps the first floppy image.
script_change_floppy() {
    echo "💾 Inserting '$1'"
    script_change_image "$1"
    sleep 1
}

# Set the next QEMU boot device.
script_set_boot() {
    if [ -z "${1:-}" ]; then
        log_error "Missing boot device for QMP boot_set command"
        return 1
    fi
    echo "🥾 Set boot device to $1"
    qmp_hmp_command "boot_set $1"
}

# Tests whether text contains expected fixed text.
text_contains_string() {
    local screen text
    screen=$1
    text=$2

    [[ $screen == *"$text"* ]]
}

# Tests whether text contains a line matching the extended regex. Anchors in
# the pattern match against individual lines, so ^ and $ mean line start/end.
text_contains_regex() {
    local screen pattern line
    screen=$1
    pattern=$2

    while IFS= read -r line; do
        if [[ $line =~ $pattern ]]; then
            return 0
        fi
    done <<<"$screen"

    return 1
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
