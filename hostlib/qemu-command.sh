# shellcheck shell=bash
# QEMU argument assembly and portable launcher command rendering.

# Quotes one argument for safe, readable reuse on a POSIX shell command line.
qemu_command_quote_posix_word() {
    local s=$1
    case $s in
    '' | *[!a-zA-Z0-9,._=:/@%+-]*)
        s=\'${s//\'/\'\\\'\'}\'
        ;;
    esac
    printf '%s' "$s"
}

# Appends a whitespace-separated argument string to QEMU_ARGS.
qemu_command_append_words() {
    local words=()
    if [[ -n "${1:-}" ]]; then
        read -ra words -d '' <<<"$1" || true
        if [[ ${#words[@]} -gt 0 ]]; then
            QEMU_ARGS+=("${words[@]}")
        fi
    fi
}

# Renders QEMU_ARGS as a POSIX shell command line.
qemu_command_render_sh() {
    local arg rendered=
    for arg in "${QEMU_ARGS[@]}"; do
        rendered="$rendered $(qemu_command_quote_posix_word "$arg")"
    done
    printf '%s\n' "${rendered# }"
}

# Renders QEMU_ARGS as a Windows cmd command line for the generated retro.bat.
qemu_command_render_cmd() {
    local arg
    local rendered=
    for arg in "${QEMU_ARGS[@]}"; do
        # A literal percent must be doubled in a batch file.
        arg=${arg//%/%%}
        case "$arg" in
        # Whitespace, quotes, or cmd.exe metacharacters: quote the argument so
        # cmd treats them literally, doubling any embedded quotes.
        *[[:space:]\"\&\|\<\>^\(\)]*)
            arg=${arg//\"/\"\"}
            rendered="$rendered \"$arg\""
            ;;
        *)
            rendered="$rendered $arg"
            ;;
        esac
    done
    printf '%s\n' "${rendered# }"
}

# Assembles the final QEMU argument array.
qemu_command_build() {
    log_debug "Assembling QEMU command"
    QEMU_ARGS=(
        "$QEMU_SYSTEM"
        -machine "$QEMU_MACHINE"
        -smp "$QEMU_SMP"
        -m "$QEMU_RAM"
    )
    if [[ -n "${QEMU_QMP_PIPE:-}" && "$QEMU_QMP_PIPE" != "none" ]]; then
        QEMU_ARGS+=(-qmp "pipe:$QEMU_QMP_PIPE")
    fi
    if [[ -n "${QEMU_MONITOR_PORT:-}" && "$QEMU_MONITOR_PORT" != "none" ]]; then
        QEMU_ARGS+=(-monitor "telnet:127.0.0.1:$QEMU_MONITOR_PORT,server=on,wait=off")
    fi
    QEMU_ARGS+=("${QEMU_SERIALS[@]}")
    QEMU_ARGS+=("${QEMU_PARALLELS[@]}")
    qemu_command_append_words "${QEMU_DISPLAY:-}"
    qemu_command_append_words "${QEMU_ACCEL:-}"
    qemu_command_append_words "${QEMU_NETWORK:-}"
    QEMU_ARGS+=("${QEMU_GLOBALS[@]}")
    QEMU_ARGS+=("${QEMU_DRIVES[@]}")
    qemu_command_append_words "${QEMU_BOOT_ORDER:-}"
    qemu_command_append_words "${QEMU_EXTRA:-}"
    QEMU_ARGS+=("$@")
    if [[ $# -gt 0 ]]; then
        log_debug "Appending user QEMU arguments: $*"
    fi
    # shellcheck disable=SC2034 # Read by qemu.sh after all modules are sourced.
    QEMU_COMMAND=$(qemu_command_render_sh)
}
