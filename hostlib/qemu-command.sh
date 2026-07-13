# shellcheck shell=bash
# QEMU argument assembly and portable launcher command rendering.

# Quotes one argument for safe, readable reuse on a POSIX shell command line.
command_quote_posix_word() {
    local s=$1
    case $s in
    '' | *[!a-zA-Z0-9,._=:/@%+-]*)
        s=\'${s//\'/\'\\\'\'}\'
        ;;
    esac
    printf '%s' "$s"
}

# Appends an option and its configured value when the value is non-empty.
command_add_option() {
    if [[ -n "${2:-}" ]]; then
        QEMU_ARGS+=("$1" "$2")
    fi
}

# Renders QEMU_ARGS as a POSIX shell command line.
command_render_sh() {
    local arg rendered=
    for arg in "${QEMU_ARGS[@]}"; do
        rendered="$rendered $(command_quote_posix_word "$arg")"
    done
    printf '%s\n' "${rendered# }"
}

# Renders QEMU_ARGS as a Windows cmd command line for the generated retro.bat.
command_render_cmd() {
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
command_build() {
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
    command_add_option -display "${QEMU_DISPLAY:-}"
    command_add_option -accel "${QEMU_ACCEL:-}"
    command_add_option -vga "${QEMU_VGA:-}"
    if [[ ${#QEMU_NETWORK[@]} -gt 0 ]]; then
        QEMU_ARGS+=("${QEMU_NETWORK[@]}")
    fi
    QEMU_ARGS+=("${QEMU_GLOBALS[@]}")
    QEMU_ARGS+=("${QEMU_DRIVES[@]}")
    command_add_option -boot "${QEMU_BOOT_ORDER:-}"
    if [[ ${#QEMU_EXTRA[@]} -gt 0 ]]; then
        QEMU_ARGS+=("${QEMU_EXTRA[@]}")
    fi
    # shellcheck disable=SC2034 # Read by qemu.sh after all modules are sourced.
    QEMU_COMMAND=$(command_render_sh)
}
