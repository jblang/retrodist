# shellcheck shell=bash
# QMP-backed keyboard helpers.

# Converts one character to a QEMU key code.
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

# Types a string into the guest, optionally followed by Return.
kb_type() {
    local send_return=false text i char key
    local codes=()

    if [ "${1:-}" = -n ]; then
        send_return=true
        shift
    fi
    [ $# -eq 1 ] || {
        log_error "kb_type requires [-n] TEXT"
        return 1
    }
    text=$1

    if [ "$send_return" = true ]; then
        echo "⌨️  $text ↩️"
    fi

    for ((i = 0; i < ${#text}; i++)); do
        char=${text:i:1}
        key=$(kb_char_to_code "$char") || {
            log_error "$(printf 'Unsupported character for QMP keyboard input: %q' "$char")"
            return 1
        }
        log_debug "Queueing '$key'"
        codes+=("$key")
    done
    if [ "$send_return" = true ]; then
        codes+=(ret)
    fi
    [ "${#codes[@]}" -eq 0 ] || kb_press "${codes[@]}" >/dev/null
}

# Reads stdin and types it one line at a time.
kb_send_stdin() {
    local line read_status

    while :; do
        IFS= read -r line
        read_status=$?
        [ "$read_status" -eq 0 ] || [ -n "$line" ] || break
        if [ "$read_status" -eq 0 ]; then
            kb_type -n "$line" >/dev/null || return 1
        else
            kb_type "$line" >/dev/null || return 1
            break
        fi
    done
}

# Presses one or more key sequences in order.
kb_press() {
    [ $# -gt 0 ] || {
        log_error "kb_press requires KEY [KEY ...]"
        return 1
    }

    echo "👇 $*"
    while [ $# -gt 0 ]; do
        qmp_hmp_command "sendkey $1" || return 1
        shift
    done
}

# Presses one QEMU key sequence one or more times.
kb_repeat() {
    local key count i
    local codes=()

    [ $# -ge 1 ] && [ $# -le 2 ] || {
        log_error "kb_repeat requires KEY [COUNT]"
        return 1
    }
    key=$1
    count=${2:-1}

    case "$count" in
    *[!0-9]*)
        log_error "kb_repeat count must be a non-negative integer: $count"
        return 1
        ;;
    esac

    if [ "$count" -gt 1 ]; then
        echo "👇 $key ($count times)"
    else
        echo "👇 $key"
    fi

    for ((i = 0; i < count; i++)); do
        codes+=("$key")
    done
    [ "${#codes[@]}" -eq 0 ] || kb_press "${codes[@]}" >/dev/null
}
