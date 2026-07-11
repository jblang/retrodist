# shellcheck shell=bash
# Serial-pipe install scripting helpers.

# Serial scripting reads the guest pipe from SERIAL_LOG and writes answers to fd 9.
# Unlike VGA text memory, the serial log never scrolls away.

# Byte offset in SERIAL_LOG already consumed by matches.
SERIAL_LINE=0

# Byte offset in SERIAL_LOG already printed in the serial transcript.
SERIAL_TRANSCRIPT_LINE=0

# Lines sent to the serial pipe that may be echoed back by the guest tty.
SERIAL_ECHO_LINES=()

# Starts draining the guest serial pipe and opens fd 9 for answers.
serial_start() {
    SERIAL_LOG=${SERIAL_LOG:-${QEMU_SERIAL_PIPE:-}.log}
    [ -p "${QEMU_SERIAL_PIPE:-}.out" ] || return 0
    : >"$SERIAL_LOG"
    SERIAL_LINE=0
    SERIAL_TRANSCRIPT_LINE=0
    SERIAL_ECHO_LINES=()
    cat "$QEMU_SERIAL_PIPE.out" >>"$SERIAL_LOG" &
    exec 9>"$QEMU_SERIAL_PIPE.in"
}

serial_echo_push() {
    SERIAL_ECHO_LINES+=("$1")
}

serial_echo_pop_if_match() {
    [ "${#SERIAL_ECHO_LINES[@]}" -gt 0 ] || return 1
    [ "${SERIAL_ECHO_LINES[0]}" = "$1" ] || return 1
    SERIAL_ECHO_LINES=("${SERIAL_ECHO_LINES[@]:1}")
}

# Prints any serial output not yet included in the transcript. Used before
# logging host input so already-arrived guest output appears first.
serial_transcript_drain() {
    local raw line read_status bytes offset
    [ -n "${SERIAL_LOG:-}" ] && [ -f "$SERIAL_LOG" ] || return 0

    offset=$SERIAL_TRANSCRIPT_LINE
    while :; do
        IFS= read -r raw
        read_status=$?
        [ "$read_status" -eq 0 ] || [ -n "$raw" ] || break

        bytes=${#raw}
        [ "$read_status" -ne 0 ] || bytes=$((bytes + 1))
        offset=$((offset + bytes))

        line=${raw//$'\r'/}
        if serial_echo_pop_if_match "$line"; then
            SERIAL_TRANSCRIPT_LINE=$offset
            if [ "$offset" -gt "$SERIAL_LINE" ]; then
                SERIAL_LINE=$offset
            fi
            [ "$read_status" -eq 0 ] || break
            continue
        fi
        echo "➡️  $line" >&2
        SERIAL_TRANSCRIPT_LINE=$offset

        [ "$read_status" -eq 0 ] || break
    done < <(dd if="$SERIAL_LOG" bs=1 skip="$SERIAL_TRANSCRIPT_LINE" 2>/dev/null)
}

# Writes one line to the guest serial pipe.
serial_send() {
    serial_transcript_drain
    printf '%s\n' "$1" >&9
    serial_echo_push "$1"
    echo "⬅️  $1" >&2
}

# Rewinds consumption so a later wait can re-match a peeked screen.
serial_rewind() {
    SERIAL_LINE=$1
}

# Scans unconsumed serial text in stream order, including partial prompt lines.
# On match, updates SERIAL_LINE, SERIAL_MATCHED, and SERIAL_MATCHED_TEXT.
serial_scan() {
    local raw line read_status bytes offset i expected_index

    offset=$SERIAL_LINE
    while :; do
        IFS= read -r raw
        read_status=$?
        [ "$read_status" -eq 0 ] || [ -n "$raw" ] || break

        bytes=${#raw}
        [ "$read_status" -ne 0 ] || bytes=$((bytes + 1))
        offset=$((offset + bytes))

        line=${raw//$'\r'/}
        if serial_echo_pop_if_match "$line"; then
            if [ "$offset" -gt "$SERIAL_TRANSCRIPT_LINE" ]; then
                SERIAL_TRANSCRIPT_LINE=$offset
            fi
            SERIAL_LINE=$offset
            [ "$read_status" -eq 0 ] || break
            continue
        fi
        for ((i = 1; i <= $#; i += 2)); do
            expected_index=$((i + 1))
            if "${!i}" "$line" "${!expected_index}"; then
                if [ "$offset" -gt "$SERIAL_TRANSCRIPT_LINE" ]; then
                    echo "✅ $line" >&2
                    SERIAL_TRANSCRIPT_LINE=$offset
                fi
                SERIAL_LINE=$offset
                SERIAL_MATCHED=$(((i - 1) / 2))
                SERIAL_MATCHED_TEXT=$line
                return 0
            fi
        done
        if [ "$offset" -gt "$SERIAL_TRANSCRIPT_LINE" ]; then
            echo "➡️  $line" >&2
            SERIAL_TRANSCRIPT_LINE=$offset
        fi
        [ "$read_status" -eq 0 ] || break
    done < <(dd if="$SERIAL_LOG" bs=1 skip="$SERIAL_LINE" 2>/dev/null)
    return 1
}

# Waits until the serial log satisfies one of the given matcher functions.
serial_wait_until() {
    local interval label
    local separator_index condition_count i
    local matchers=() expected=() pairs=()

    separator_index=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" = "--" ]; then
            separator_index=$i
            break
        fi
    done

    if [ "$separator_index" -eq 0 ]; then
        if [ $# -lt 2 ]; then
            die "serial_wait_until requires MATCHER EXPECTED"
        fi
        if [ $# -ne 2 ]; then
            die "serial_wait_until single-condition form requires exactly MATCHER EXPECTED"
        fi
        matchers=("$1")
        expected=("$2")
    else
        if [ $(((separator_index - 1) % 2)) -ne 0 ] || [ "$separator_index" -eq 1 ]; then
            die "serial_wait_until conditions must be MATCHER EXPECTED pairs"
        fi
        if [ "$separator_index" -ne "$#" ]; then
            die "serial_wait_until does not accept arguments after --"
        fi
        local expected_index
        for ((i = 1; i < separator_index; i += 2)); do
            expected_index=$((i + 1))
            matchers+=("${!i}")
            expected+=("${!expected_index}")
        done
    fi
    interval=${WAIT_INTERVAL:-0.1}
    condition_count=${#matchers[@]}
    label=${expected[0]}
    for ((i = 1; i < condition_count; i++)); do
        label="$label' || '${expected[$i]}"
    done
    for ((i = 0; i < condition_count; i++)); do
        pairs+=("${matchers[$i]}" "${expected[$i]}")
    done
    while :; do
        if ! qmp_qemu_running; then
            die "QEMU exited while waiting for serial match: $label"
        fi

        if serial_scan "${pairs[@]}"; then
            printf '%s\n' "$SERIAL_MATCHED_TEXT"
            return "$SERIAL_MATCHED"
        fi

        sleep "$interval"
    done
}

# Waits for one serial matcher/text pair. Transcript output from
# serial_wait_until is the only progress display.
serial_wait_one() {
    local matcher expected
    [ $# -eq 2 ] || die "serial_wait_one requires MATCHER TEXT"
    matcher=$1
    expected=$2

    serial_wait_until "$matcher" "$expected" >/dev/null
}

# Waits for any expected serial text; -l is full-line, -r is regex.
serial_wait_alternative() {
    local status matcher
    local args=() expected
    matcher=text_contains_string

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
        --)
            shift
            break
            ;;
        -*)
            die "serial_wait_alternative unknown option: $1"
            ;;
        *)
            break
            ;;
        esac
    done

    [ $# -gt 0 ] || die "serial_wait_alternative requires [-l] [-r] TEXT [TEXT ...]"
    for expected in "$@"; do
        args+=("$matcher" "$expected")
    done
    args+=(--)
    serial_wait_until "${args[@]}" >/dev/null
    status=$?
    return "$status"
}

# Waits for serial text; default is substring, -l is full-line, -r is regex.
serial_wait() {
    local expected matcher=text_contains_string

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
        --)
            shift
            break
            ;;
        -*)
            die "serial_wait unknown option: $1"
            ;;
        *)
            break
            ;;
        esac
    done

    [ $# -gt 0 ] || die "serial_wait requires [-l] [-r] TEXT [TEXT ...]"
    for expected in "$@"; do
        serial_wait_one "$matcher" "$expected" || return 1
    done
}

# Waits for serial prompt lines, then sends the final argument as the answer.
serial_prompt() {
    local last final_i question answer i
    local matcher=text_contains_line

    if [ "$1" = "-r" ]; then
        matcher=text_contains_regex
        shift
    fi

    [ $# -ge 2 ] || die "serial_prompt requires [-r] QUESTION [QUESTION ...] ANSWER"
    last=$#
    answer=${!last}
    final_i=$((last - 1))

    for ((i = 1; i <= final_i; i++)); do
        question=${!i}
        serial_wait_one "$matcher" "$question" >/dev/null
    done

    serial_send "$answer" || return 1
}

# Starts an interactive shell whose stdio is the guest serial port.
serial_shell_start() {
    local prompt dev minor launcher

    prompt=${SERIAL_SHELL_PROMPT:-#}
    dev=${SERIAL_SHELL_DEV:-${SERIAL_DEV:-/dev/ttyS3}}
    minor=${SERIAL_SHELL_MINOR:-67}
    launcher="[ -c $(qemu_command_quote_posix_word "$dev") ] || mknod $(qemu_command_quote_posix_word "$dev") c 4 $(qemu_command_quote_posix_word "$minor"); PS1=$(qemu_command_quote_posix_word "$prompt ") sh -i <$(qemu_command_quote_posix_word "$dev") >$(qemu_command_quote_posix_word "$dev") 2>&1"

    vga_wait -l "$SHELL_PROMPT"
    kb_send_line "$launcher" || return 1
    serial_wait -l "$prompt"
}

# Sends one command to the active serial shell.
serial_shell_send() {
    local cmd prompt wait_return=true

    if [ "${1:-}" = "--no-wait" ]; then
        wait_return=false
        shift
    fi
    [ $# -eq 1 ] || die "serial_shell_send requires [--no-wait] COMMAND"
    cmd=$1
    prompt=${SERIAL_SHELL_PROMPT:-#}

    serial_send "$cmd" || return 1
    [ "$wait_return" = false ] || serial_wait -l "$prompt"
}

# Exits the active serial shell and waits for the screen shell prompt.
serial_shell_exit() {
    serial_send "exit" || return 1
    vga_wait -l "$SHELL_PROMPT"
}

# Starts a serial shell, sends commands, and optionally exits it.
serial_shell() {
    local cmd wait_return=true

    if [ "${1:-}" = "--no-wait" ]; then
        wait_return=false
        shift
    fi
    [ $# -gt 0 ] || die "serial_shell requires [--no-wait] COMMAND [COMMAND ...]"

    serial_shell_start || return 1
    for cmd in "$@"; do
        if [ "$wait_return" = true ]; then
            serial_shell_send "$cmd" || return 1
        else
            serial_shell_send --no-wait "$cmd" || return 1
        fi
    done
    [ "$wait_return" = false ] || serial_shell_exit
}
