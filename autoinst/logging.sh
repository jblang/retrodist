# logging helpers

# Can't rely on backslash interpolation so we use literal esc chars.
LOG_BLUE='[1;34m'
LOG_GREEN='[1;32m'
LOG_YELLOW='[1;33m'
LOG_RED='[1;31m'
LOG_MAGENTA='[1;35m'
LOG_WHITE='[1;37m'
LOG_GREY='[0;37m'

log_write() {
    LOG_LEVEL=$1
    LOG_COLOR=$2
    shift
    shift
    echo "${LOG_COLOR}${LOG_LEVEL}${LOG_GREY}: $*" >&2
    if [ -n "$AUTOINST_LOG" ]; then
        echo "$LOG_LEVEL: $*" >> "$AUTOINST_LOG"
    fi
}

log_debug() {
    if [ "$AUTOINST_DEBUG" != "1" ]; then
        return 0
    fi
    log_write DEBUG "$LOG_BLUE" "$@"
}

log_info() {
    log_write INFO "$LOG_GREEN" "$@"
}

log_warn() {
    log_write WARN "$LOG_YELLOW" "$@"
}

log_error() {
    log_write ERROR "$LOG_RED" "$@"
}

log_attention() {
    log_write ATTN "$LOG_MAGENTA" "$@"
}

log_div() {
    echo "--------------------------------------------------------------------------------" >&2
    if [ -n "$AUTOINST_LOG" ]; then
        echo "--------------------------------------------------------------------------------" >> "$AUTOINST_LOG"
    fi
}
