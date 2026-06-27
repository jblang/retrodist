# shellcheck shell=sh
# logging helpers

# Can't rely on backslash interpolation so we use literal esc chars.
LOG_BLUE='[1;34m'
LOG_GREEN='[1;32m'
LOG_YELLOW='[1;33m'
LOG_RED='[1;31m'
LOG_MAGENTA='[1;35m'
LOG_WHITE='[1;37m'
LOG_GREY='[0;37m'

# Write one log message to stderr and AUTOINST_LOG when configured.
log_write() {
    LOG_LEVEL=$1
    LOG_COLOR=$2
    shift
    shift
    echo "${LOG_COLOR}${LOG_LEVEL}${LOG_GREY}: $*" >&2
    if [ -n "$AUTOINST_LOG" ]; then
        echo "$LOG_LEVEL: $*" >>"$AUTOINST_LOG"
    fi
}

# Log a debug message when debug logging is enabled.
log_debug() {
    if [ "$AUTOINST_DEBUG" != "1" ]; then
        return 0
    fi
    log_write DEBUG "$LOG_BLUE" "$@"
}

# Log an informational message.
log_info() {
    log_write INFO "$LOG_GREEN" "$@"
}

# Log a warning message.
log_warn() {
    log_write WARN "$LOG_YELLOW" "$@"
}

# Log an error message.
log_error() {
    log_write ERROR "$LOG_RED" "$@"
}

# Log an operator attention message.
log_attention() {
    log_write ATTN "$LOG_MAGENTA" "$@"
}

# Log a divider line.
log_div() {
    echo "--------------------------------------------------------------------------------" >&2
    if [ -n "$AUTOINST_LOG" ]; then
        echo "--------------------------------------------------------------------------------" >>"$AUTOINST_LOG"
    fi
}

# Log an error and abort the install or configuration run.
die() {
    log_error "$1"
    exit 1
}
