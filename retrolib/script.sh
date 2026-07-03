# shellcheck shell=bash
# Reusable QMP-driven install script building blocks.

# command to mount fat partition and run autoinst
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SCRIPT_AUTOINST_COMMAND="mkdir /retro && mount -t msdos /dev/hdb1 /retro && sh /retro/autoinst"

# command to find the staged fat partition and run first-boot autoconf
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
SCRIPT_AUTOCONF_COMMAND='if [ ! -d /retro/autoinst.d ]; then mkdir -p /retro && mount -t msdos /dev/hdb1 /retro; fi; /retro/autoinst.d/autoconf.sh'

# Extracts disk geometry from fdisk output currently visible on the guest screen.
script_parse_fdisk_geometry() {
    local screen
    screen=$1

    if [[ $screen =~ ([0-9]+)[[:space:]]+heads,[[:space:]]+([0-9]+)[[:space:]]+sectors(/track)?,[[:space:]]+([0-9]+)[[:space:]]+cylinders ]]; then
        printf '%s %s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[4]}"
        return 0
    fi

    return 1
}

# Tests whether screen text contains an fdisk geometry line.
script_screen_contains_fdisk_geometry() {
    local screen
    screen=$1

    script_parse_fdisk_geometry "$screen" >/dev/null
}

# Calculates the default swap/root partition cylinder layout on the host.
script_calculate_swaproot_geometry() {
    local heads sectors cylinders swap_mb
    local sectors_per_cylinder swap_sectors half_cylinder swap_end root_start
    if [[ $# -ne 4 ]]; then
        log_error "Usage: script_calculate_swaproot_geometry HEADS SECTORS CYLINDERS SWAP_MB"
        return 1
    fi

    heads=$1
    sectors=$2
    cylinders=$3
    swap_mb=$4

    case "$heads:$sectors:$cylinders:$swap_mb" in
    *[!0-9:]* | *::* | :* | *:)
        log_error "Invalid fdisk geometry values: heads=$heads sectors=$sectors cylinders=$cylinders swap_mb=$swap_mb"
        return 1
        ;;
    esac

    sectors_per_cylinder=$((heads * sectors))
    if [[ $sectors_per_cylinder -lt 1 ]]; then
        log_error "Invalid fdisk sectors per cylinder: $sectors_per_cylinder"
        return 1
    fi

    swap_sectors=$((swap_mb * 2048))
    half_cylinder=$((sectors_per_cylinder / 2))
    swap_end=$(((swap_sectors + half_cylinder) / sectors_per_cylinder))
    root_start=$((swap_end + 1))

    if [[ $swap_end -lt 1 || $swap_end -ge $cylinders ]]; then
        log_error "Swap size is too large for disk geometry: swap_end=$swap_end cylinders=$cylinders"
        return 1
    fi

    printf '1 %s %s %s\n' "$swap_end" "$root_start" "$cylinders"
}

# Detects guest fdisk geometry and calculates the default swap/root layout.
script_detect_swaproot_geometry() {
    local device swap_mb geometry_script
    local screen geometry heads sectors cylinders layout wait_status
    local swap_start swap_end root_start root_end
    local device_q geometry_script_q geometry_success geometry_error

    if [[ $# -ne 3 ]]; then
        log_error "Usage: script_detect_swaproot_geometry DEVICE SWAP_MB GEOMETRY_SCRIPT"
        return 1
    fi

    device=$1
    swap_mb=$2
    geometry_script=$3

    device_q=$(shell_quote_word "$device")
    geometry_script_q=$(shell_quote_word "$geometry_script")

    geometry_success="geometry.sh: fdisk geometry query suceeded"
    geometry_error="geometry.sh: fdisk geometry query returned error "
    script_shell "sh $geometry_script_q $device_q"
    script_wait_string "$geometry_success" "$geometry_error"
    wait_status=$?
    if [ "$wait_status" -ne 0 ]; then
        die "Guest fdisk helper failed during geometry query."
    fi
    screen=$(qmp_vga_dump_text) ||
        die "Unable to read guest screen after fdisk geometry query."
    geometry=$(script_parse_fdisk_geometry "$screen") ||
        die "Unable to parse fdisk geometry for $device from guest screen."

    read -r heads sectors cylinders <<<"$geometry"
    layout=$(script_calculate_swaproot_geometry "$heads" "$sectors" "$cylinders" "$swap_mb") ||
        die "Unable to calculate partition geometry for $device."
    read -r swap_start swap_end root_start root_end <<<"$layout"

    log_info "Detected $device geometry: heads=$heads sectors=$sectors cylinders=$cylinders"
    log_info "Partition geometry: swap=$swap_start-$swap_end root=$root_start-$root_end"

    SCRIPT_SWAPROOT_GEOMETRY=$layout
    SCRIPT_SWAPROOT_ROOT_START=$root_start
    SCRIPT_SWAPROOT_ROOT_END=$root_end
}

# Creates guest swap/root partitions using an already-calculated layout.
script_create_swaproot_partitions() {
    local device swaproot_script layout root_start root_end
    local device_q swaproot_script_q swaproot_success swaproot_error wait_status

    if [[ $# -ne 5 ]]; then
        log_error "Usage: script_create_swaproot_partitions DEVICE SWAPROOT_SCRIPT LAYOUT ROOT_START ROOT_END"
        return 1
    fi

    device=$1
    swaproot_script=$2
    layout=$3
    root_start=$4
    root_end=$5
    device_q=$(shell_quote_word "$device")
    swaproot_script_q=$(shell_quote_word "$swaproot_script")

    swaproot_success="swaproot.sh: created root partition ${device}2 from $root_start-$root_end"
    swaproot_error="swaproot.sh: fdisk partition creation returned error "
    script_shell "sh $swaproot_script_q $device_q $layout"
    script_wait_string "$swaproot_success" "$swaproot_error" ||
        die "Guest fdisk helper failed during partition creation."
}

# Partitions a guest disk by probing fdisk geometry in the guest, calculating
# the layout on the host, then calling the guest fdisk command emitter.
script_partition_swaproot() {
    local device swap_mb autoinst_mount geometry_script swaproot_script
    if [[ $# -lt 2 || $# -gt 3 ]]; then
        log_error "Usage: script_partition_swaproot DEVICE SWAP_MB [AUTOINST_MOUNT]"
        return 1
    fi

    device=$1
    swap_mb=$2
    autoinst_mount=${3:-/mnt}
    geometry_script=$autoinst_mount/autoinst.d/fdisk/geometry.sh
    swaproot_script=$autoinst_mount/autoinst.d/fdisk/swaproot.sh

    SCRIPT_SWAPROOT_GEOMETRY=
    SCRIPT_SWAPROOT_ROOT_START=
    SCRIPT_SWAPROOT_ROOT_END=

    script_detect_swaproot_geometry "$device" "$swap_mb" "$geometry_script" || return 1
    script_create_swaproot_partitions \
        "$device" \
        "$swaproot_script" \
        "$SCRIPT_SWAPROOT_GEOMETRY" \
        "$SCRIPT_SWAPROOT_ROOT_START" \
        "$SCRIPT_SWAPROOT_ROOT_END" || return 1
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
    interval=${WAIT_INTERVAL:-1}
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

# Echoes the waiting message for a set of alternative screen matches.
script_wait_message() {
    local expected
    [ $# -gt 0 ] || die "script_wait_message requires TEXT [TEXT ...]"

    if [ "$#" -gt 1 ]; then
        printf "🔀 Awaiting alternatives:\n"
        for expected in "$@"; do
            printf "   %s\n" "$expected"
        done
    else
        printf "⏳ %s" "$1"
    fi
}

# Echoes the result from the most recent successful script_wait_until call.
script_wait_result() {
    local status expected expected_index alternative_count
    [ $# -gt 1 ] || die "script_wait_result requires STATUS TEXT [TEXT ...]"
    status=$1
    shift
    alternative_count=$#
    expected_index=$((status + 1))
    expected=${!expected_index}

    if [ "$alternative_count" -gt 1 ]; then
        printf "✅ %s\n" "$expected"
    else
        printf "\r✅ %s\033[K\n" "$expected"
    fi

    return 0
}

# Waits until VGA text memory contains expected screen text anywhere.
script_wait_string() {
    local status args=() expected
    [ $# -gt 0 ] || die "script_wait_string requires TEXT [TEXT ...]"
    for expected in "$@"; do
        args+=(script_screen_contains_string "$expected")
    done
    args+=(--)
    script_wait_message "$@"
    script_wait_until "${args[@]}" >/dev/null
    status=$?
    script_wait_result "$status" "$@"
    return "$status"
}

# Waits until VGA text memory contains expected text on a line by itself.
script_wait_line() {
    local status args=() expected
    [ $# -gt 0 ] || die "script_wait_line requires TEXT [TEXT ...]"
    for expected in "$@"; do
        args+=(script_screen_contains_line "$expected")
    done
    args+=(--)
    script_wait_message "$@"
    script_wait_until "${args[@]}" >/dev/null
    status=$?
    script_wait_result "$status" "$@"
    return "$status"
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
        printf "\r🐚 %s %s\033[K\n" "$SHELL_PROMPT" "$cmd"
        qmp_send_string "$cmd" || return 1
        qmp_sendkey ret || return 1
    done

    if [ "$wait_return" = true ]; then
        printf "⏳ %s" "$SHELL_PROMPT"
        script_wait_line "$SHELL_PROMPT" >/dev/null
		printf "\r\033[K"
    fi
}

# Boot loader prompt script_boot waits for; override to match the guest's boot loader.
# shellcheck disable=SC2034 # Used by distro install scripts sourced at runtime.
BOOT_PROMPT="boot:"

# Waits for the boot loader prompt, then sends a string (or just Enter if none given).
script_boot() {
    local response

    printf "⏳ %s" "$BOOT_PROMPT"
    script_wait_line "$BOOT_PROMPT" >/dev/null

    if [ $# -gt 0 ]; then
        response=$1
        qmp_send_string "$response" || return 1
    else
        response="↩️"
    fi
    qmp_sendkey ret || return 1

    printf "\r🥾 %s %s\033[K\n" "$BOOT_PROMPT" "$response"
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
script_prompt() {
    local last final_i question answer i marker

    [ $# -ge 2 ] || die "script_prompt requires QUESTION [QUESTION ...] ANSWER"
    last=$#
    answer=${!last}
    final_i=$((last - 1))

    for ((i = 1; i <= final_i; i++)); do
        question=${!i}
        printf "⏳ %s" "$question"
        script_wait_line "$question" >/dev/null
        marker="  "
        [ "$i" -eq 1 ] && marker="💬"
        [ "$i" -lt "$final_i" ] && printf "\r%s %s\033[K\n" "$marker" "$question"
    done

    qmp_send_string "$answer" || return 1
    qmp_sendkey ret || return 1

    marker="  "
    [ "$final_i" -eq 1 ] && marker="💬"
    printf "\r%s %s %s\033[K\n" "$marker" "$question" "$answer"
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
