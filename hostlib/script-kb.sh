# shellcheck shell=bash
# QMP-backed keyboard helpers.

# Sends a raw QEMU sendkey key code.
kb_send_raw() {
    if [ -z "${1:-}" ]; then
        log_error "Missing key code for QMP sendkey command"
        return 1
    fi
    log_debug "Sending QEMU key sequence $1"
    qmp_hmp_command "sendkey $1"
}

# Converts one character to a QEMU sendkey code.
kb_char_to_code() {
    local LC_ALL=C	# Force C collation so [a-z]/[A-Z] match by byte.

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
kb_send_string() {
    local text i char key
    text=${1:-}

    for ((i = 0; i < ${#text}; i++)); do
        char=${text:i:1}
        key=$(kb_char_to_code "$char") || {
            log_error "$(printf 'Unsupported character for QMP sendkey: %q' "$char")"
            return 1
        }
		log_debug "Sending '$key'"
        kb_send_raw "$key"
    done
}

# Reads stdin and types it into the guest.
kb_send_stdin() {
    local char key

    # Read one byte at a time so trailing newlines are preserved.
    while IFS= read -r -n 1 char; do
        if [ -z "$char" ]; then
            char=$'\n'
        fi
        key=$(kb_char_to_code "$char") || {
            log_error "$(printf 'Unsupported character for QMP sendkey: %q' "$char")"
            return 1
        }
        kb_send_raw "$key" || return 1
    done
}

# Sends Return to the guest.
kb_send_return() {
    kb_send_raw ret
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
        kb_send_raw "$key" || return 1
        count=$((count - 1))
    done
}

# Sends a string followed by return with QMP keyboard input.
kb_send_line() {
	echo "⌨️  $1 ↩️"
	kb_send_string "$1" || return 1
	kb_send_return || return 1
}
