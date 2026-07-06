# shellcheck shell=bash
# Reusable QMP-driven install script building blocks.

# command to mount fat partition and run autoinst
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SCRIPT_AUTOINST_COMMAND="mkdir /retro && mount -t msdos /dev/hdb1 /retro && sh /retro/autoinst"

# command to find the staged fat partition and run first-boot autoconf
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SCRIPT_AUTOCONF_COMMAND='if [ ! -d /retro/autoinst.d ]; then mkdir -p /retro && mount -t msdos /dev/hdb1 /retro; fi; /retro/autoinst.d/autoconf.sh'

# Sources a shared helper by path relative to the install script's directory.
# Exits the install subshell on failure so a missing or syntactically broken
# helper aborts immediately instead of surfacing later as "command not found".
script_import() {
    local helper
    if [[ -z "${QEMU_INSTALL_SCRIPT:-}" ]]; then
        die "script_import requires QEMU_INSTALL_SCRIPT to be set"
    fi
    helper=$(dirname "$QEMU_INSTALL_SCRIPT")/$1
    # shellcheck source=/dev/null
    source "$helper" || die "Failed to import $helper"
}

# Extended regex for a bare fdisk cylinder prompt still awaiting input; the
# available first-last range fdisk advertises in parentheses is captured.
# Some fdisks bracket the default value, e.g. ([1]-520); newer ones append
# ", default N" instead.
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

# Waits for a bare fdisk prompt advertising a cylinder range and stores the
# range in SCRIPT_FDISK_FIRST/SCRIPT_FDISK_LAST.
script_fdisk_wait_range() {
    local label pattern screen line range

    [ $# -eq 2 ] || die "script_fdisk_wait_range requires LABEL PATTERN"
    label=$1
    pattern=$2

    script_wait_message "$label"
    screen=$(script_wait_until script_screen_contains_regex "$pattern")
    script_wait_result "$label"

    line=$(grep -E -- "$pattern" <<<"$screen" | tail -n 1)
    range=$(script_fdisk_parse_range "$line") || {
        log_error "Unable to parse fdisk cylinder range: $line"
        return 1
    }
    read -r SCRIPT_FDISK_FIRST SCRIPT_FDISK_LAST <<<"$range"
}

# Creates swap and root partitions by driving fdisk at its interactive
# prompts. The swap partition is sized with fdisk's +sizeM shorthand and the
# root partition takes the remaining cylinders fdisk advertises, so no
# geometry math is needed on the host.
script_fdisk() {
    local device swap_mb first_prompt last_prompt

    if [[ $# -ne 2 ]]; then
        log_error "Usage: script_fdisk DEVICE SWAP_MB"
        return 1
    fi

    device=$1
    swap_mb=$2
    first_prompt="First cylinder $SCRIPT_FDISK_RANGE"
    last_prompt="Last cylinder .*$SCRIPT_FDISK_RANGE"

    script_shell --no-wait "fdisk $device"

    # delete any partitions left over from a previous run; fdisk silently
    # clears slots that are already empty, so this is safe on a fresh disk
    script_prompt "Command (m for help):" "d"
    script_prompt "Partition number (1-4):" "1"
    script_prompt "Command (m for help):" "d"
    script_prompt "Partition number (1-4):" "2"

    # swap partition, sized in MB
    script_prompt "Command (m for help):" "n"
    script_send_line "p" # primary; fdisk buffers this while printing the menu
    script_prompt "Partition number (1-4):" "1"
    script_fdisk_wait_range "First cylinder" "$first_prompt" || return 1
    script_send_line "$SCRIPT_FDISK_FIRST"
    script_fdisk_wait_range "Last cylinder" "$last_prompt" || return 1
    script_send_line "+${swap_mb}M"

    # root partition filling the rest of the disk
    script_prompt "Command (m for help):" "n"
    script_send_line "p" # primary
    script_prompt "Partition number (1-4):" "2"
    script_fdisk_wait_range "First cylinder" "$first_prompt" || return 1
    script_send_line "$SCRIPT_FDISK_FIRST"
    script_fdisk_wait_range "Last cylinder" "$last_prompt" || return 1
    script_send_line "$SCRIPT_FDISK_LAST"

    # partition types: Linux swap and Linux native
    script_prompt "Command (m for help):" "t"
    script_prompt "Partition number (1-4):" "1"
    script_prompt "Hex code (type L to list codes):" "82"
    script_prompt "Command (m for help):" "t"
    script_prompt "Partition number (1-4):" "2"
    script_prompt "Hex code (type L to list codes):" "83"

    # write the table and wait for fdisk to exit back to the shell
    script_prompt "Command (m for help):" "p"
    script_prompt "Command (m for help):" "w"
    script_wait_line "$SHELL_PROMPT"
}

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

# Tests whether screen text contains a substring matching an extended regex.
script_screen_contains_regex() {
    local screen pattern
    screen=$1
    pattern=$2

    grep -E -- "$pattern" <<<"$screen" >/dev/null
}

# Waits until VGA text memory satisfies one of the given matcher functions.
script_wait_until() {
    local interval screen label
    local separator_index condition_count i
    local matchers=() expected=()

    separator_index=0
    for ((i = 1; i <= $#; i++)); do
        if [ "${!i}" = "--" ]; then
            separator_index=$i
            break
        fi
    done

    if [ "$separator_index" -eq 0 ]; then
        if [ $# -lt 2 ]; then
            die "script_wait_until requires MATCHER EXPECTED"
        fi
        if [ $# -ne 2 ]; then
            die "script_wait_until single-condition form requires exactly MATCHER EXPECTED"
        fi
        matchers=("$1")
        expected=("$2")
    else
        if [ $(((separator_index - 1) % 2)) -ne 0 ] || [ "$separator_index" -eq 1 ]; then
            die "script_wait_until conditions must be MATCHER EXPECTED pairs"
        fi
        if [ "$separator_index" -ne "$#" ]; then
            die "script_wait_until does not accept arguments after --"
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
    while :; do
        if ! qmp_qemu_running; then
            die "QEMU exited while waiting for screen match: $label"
        fi

        if screen=$(qmp_vga_dump_text); then
            for ((i = 0; i < condition_count; i++)); do
                if "${matchers[$i]}" "$screen" "${expected[$i]}"; then
                    printf '%s\n' "$screen"
                    return "$i"
                fi
            done
        fi

        sleep "$interval"
    done
}

# Echoes the waiting message for one screen match.
script_wait_message() {
    [ $# -eq 1 ] || die "script_wait_message requires TEXT"

    printf "⏳ %s" "$1"
}

# Echoes a successful wait result.
script_wait_result() {
    [ $# -eq 1 ] || die "script_wait_result requires TEXT"

    printf "\r🖥️  %s\033[K\n" "$1"
    return 0
}

# Waits for one screen matcher/text pair and prints progress.
script_wait_one() {
    local matcher expected
    [ $# -eq 2 ] || die "script_wait_one requires MATCHER TEXT"
    matcher=$1
    expected=$2

    script_wait_message "$expected"
    script_wait_until "$matcher" "$expected" >/dev/null
    script_wait_result "$expected"
}

# Waits until VGA text memory contains any one of the expected screen texts.
# Pass -l to match alternatives as trimmed full lines instead of substrings.
# Pass -r to match alternatives as extended regex patterns instead of substrings.
# Pass -e to echo the matched alternative.
script_wait_alternative() {
    local status matcher matched_index matched
    local echo_match=false
    local args=() expected
    matcher=script_screen_contains_string

    while [ $# -gt 0 ]; do
        case "$1" in
        -l)
            matcher=script_screen_contains_line
            shift
            ;;
        -r)
            matcher=script_screen_contains_regex
            shift
            ;;
        -e)
            echo_match=true
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            die "script_wait_alternative unknown option: $1"
            ;;
        *)
            break
            ;;
        esac
    done

    [ $# -gt 0 ] || die "script_wait_alternative requires [-l] [-r] [-e] TEXT [TEXT ...]"
    printf "🔀 Awaiting %s alternatives... " "$#"
    for expected in "$@"; do
        args+=("$matcher" "$expected")
    done
    args+=(--)
    script_wait_until "${args[@]}" >/dev/null
    status=$?
    matched_index=$((status + 1))
    matched=${!matched_index}
    if [ "$echo_match" = true ]; then
        printf "matched #%s\n🖥️  %s\n" "$status" "$matched"
    else
        printf "matched #%s\n" "$status"
    fi
    return "$status"
}

# Waits until VGA text memory contains expected screen text anywhere.
# Pass -r to match TEXT as an extended regex pattern instead of a substring.
script_wait_string() {
    local expected matcher=script_screen_contains_string
    if [ "$1" = "-r" ]; then
        matcher=script_screen_contains_regex
        shift
    fi
    [ $# -gt 0 ] || die "script_wait_string requires [-r] TEXT [TEXT ...]"
    for expected in "$@"; do
        script_wait_one "$matcher" "$expected" || return 1
    done
}

# Waits until VGA text memory contains expected text on a line by itself.
# Pass -r to match TEXT as an extended regex pattern instead of a full line.
script_wait_line() {
    local expected matcher=script_screen_contains_line
    if [ "$1" = "-r" ]; then
        matcher=script_screen_contains_regex
        shift
    fi
    [ $# -gt 0 ] || die "script_wait_line requires [-r] TEXT [TEXT ...]"
    for expected in "$@"; do
        script_wait_one "$matcher" "$expected" || return 1
    done
}

# Sends one QEMU sendkey token to the guest one or more times.
script_press_key() {
    local key count times
    key=$1
    count=${2:-1}

    case "$count" in
    *[!0-9]*)
        log_error "script_press_key count must be a non-negative integer: $count"
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

# Sends a string
script_send_text() {
	echo "⌨️  $1"
	qmp_send_string "$1" || return 1
}

# Sends a string followed by return
script_send_line() {
	echo "⌨️  $1 ↩️"
	qmp_send_string "$1" || return 1
	qmp_sendkey ret || return 1
}

# Shell prompt script_shell waits for; override to match the guest's prompt.
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SHELL_PROMPT="#"

# Waits for the shell prompt, sends commands, then waits for it to return (pass --no-wait to skip).
script_shell() {
    local cmd wait_return=true

    if [ "$1" = "--no-wait" ]; then
        wait_return=false
        shift
    fi
    [ $# -gt 0 ] || die "script_shell requires COMMAND [COMMAND ...]"

    for cmd in "$@"; do
        printf "⏳ %s" "$SHELL_PROMPT"
        script_wait_line "$SHELL_PROMPT" >/dev/null
        printf "\r⚙️  %s %s\033[K\n" "$SHELL_PROMPT" "$cmd"
        qmp_send_string "$cmd" || return 1
        qmp_sendkey ret || return 1
    done

    if [ "$wait_return" = true ]; then
        printf "⏳ %s" "$SHELL_PROMPT"
        script_wait_line "$SHELL_PROMPT" >/dev/null
		printf "\r\033[K"
    fi
}

# Login prompt script_login waits for; override to match the guest's hostname.
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
LOGIN_PROMPT="login:"

# Waits for the login prompt, then sends a username (or root if none given).
script_login() {
    local response

    printf "⏳ %s" "$LOGIN_PROMPT"
    script_wait_line "$LOGIN_PROMPT" >/dev/null

    response=${1:-root}
    qmp_send_string "$response" || return 1
    qmp_sendkey ret || return 1

    printf "\r🔑 %s %s\033[K\n" "$LOGIN_PROMPT" "$response"
}

# Waits for a question prompt (pass multiple wrapped lines if it spans more than one), then sends the final argument as the answer.
# Pass -r to match QUESTION lines as extended regex patterns instead of literal text.
script_prompt() {
    local last final_i question answer i
    local matcher=script_screen_contains_line

    if [ "$1" = "-r" ]; then
        matcher=script_screen_contains_regex
        shift
    fi

    [ $# -ge 2 ] || die "script_prompt requires [-r] QUESTION [QUESTION ...] ANSWER"
    last=$#
    answer=${!last}
    final_i=$((last - 1))

    for ((i = 1; i <= final_i; i++)); do
        question=${!i}
        printf "⏳ %s" "$question"
        script_wait_one "$matcher" "$question" >/dev/null
        printf "\r🖥️  %s\033[K\n" "$question"
    done

    script_send_line "$answer" || return 1
}

# Logs in as root after first boot and runs autoconf. Pass the root password
# only for installers that configured one.
script_run_autoconf() {
    local password

    script_login

    if [ "$#" -gt 0 ]; then
        password=$1
        script_wait_string "Password:"
        script_send_line "$password"
    else
        sleep 1
        script_press_key ret
    fi

    script_shell --no-wait "$SCRIPT_AUTOCONF_COMMAND"
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
