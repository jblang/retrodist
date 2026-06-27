# shellcheck shell=bash
# Host-side logging helpers.

# Each level marker can be replaced by callers with plain text, ANSI-styled
# text, or another symbol. Example:
#   RETRO_LOG_WARN=$'\e[1;33mWARN\e[0m' retro boot slackware/3.0/walnut
if [[ ! ${RETRO_LOG_DEBUG+x} ]]; then
    RETRO_LOG_DEBUG=🐞
fi
if [[ ! ${RETRO_LOG_INFO+x} ]]; then
    RETRO_LOG_INFO="ℹ️ "
fi
if [[ ! ${RETRO_LOG_WARN+x} ]]; then
    RETRO_LOG_WARN="⚠️ "
fi
if [[ ! ${RETRO_LOG_ERROR+x} ]]; then
    RETRO_LOG_ERROR="❌"
fi
if [[ ! ${RETRO_LOG_ATTENTION+x} ]]; then
    RETRO_LOG_ATTENTION="📣 "
fi
if [[ ! ${RETRO_LOG_DIVIDER+x} ]]; then
    printf -v RETRO_LOG_DIVIDER '%80s' ''
    RETRO_LOG_DIVIDER=${RETRO_LOG_DIVIDER// /-}
fi

# Write one log message to stderr and RETRO_LOG_FILE when configured.
log_write() {
    local marker
    marker=$1
    shift

    if [[ -n "$marker" ]]; then
        printf '%s %s\n' "$marker" "$*" >&2
    else
        printf '%s\n' "$*" >&2
    fi

    if [[ -n "${RETRO_LOG_FILE:-}" ]]; then
        if [[ -n "$marker" ]]; then
            printf '%s %s\n' "$marker" "$*" >>"$RETRO_LOG_FILE"
        else
            printf '%s\n' "$*" >>"$RETRO_LOG_FILE"
        fi
    fi
}

# Log a debug message when debug logging is enabled.
log_debug() {
    if [[ "${RETRO_DEBUG:-0}" != "1" ]]; then
        return 0
    fi
    log_write "$RETRO_LOG_DEBUG" "$@"
}

# Log an informational message.
log_info() {
    log_write "$RETRO_LOG_INFO" "$@"
}

# Log a warning message.
log_warn() {
    log_write "$RETRO_LOG_WARN" "$@"
}

# Log an error message.
log_error() {
    log_write "$RETRO_LOG_ERROR" "$@"
}

# Log an operator attention message.
log_attention() {
    log_write "$RETRO_LOG_ATTENTION" "$@"
}

# Log a divider line.
log_div() {
    printf '%s\n' "$RETRO_LOG_DIVIDER" >&2
    if [[ -n "${RETRO_LOG_FILE:-}" ]]; then
        printf '%s\n' "$RETRO_LOG_DIVIDER" >>"$RETRO_LOG_FILE"
    fi
}

# Log an error and exit.
die() {
    log_error "$@"
    exit 1
}
