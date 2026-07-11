# shellcheck shell=sh
# logging helpers

# Write a levelled message to stderr and POSTINST_LOG when configured.
# INFO messages are unprefixed; DEBUG messages require POSTINST_DEBUG=1.
log() {
    LOG_LEVEL=$1
    shift

    case "$LOG_LEVEL" in
    DEBUG)
        if [ "$POSTINST_DEBUG" != "1" ]; then
            return 0
        fi
        LOG_PREFIX='DEBUG: '
        ;;
    INFO)
        LOG_PREFIX=
        ;;
    *)
        LOG_PREFIX="$LOG_LEVEL: "
        ;;
    esac

    echo "$LOG_PREFIX$*" >&2
    if [ -n "$POSTINST_LOG" ]; then
        echo "$LOG_PREFIX$*" >>"$POSTINST_LOG"
    fi
}

# Log a divider line.
log_div() {
    echo "--------------------------------------------------------------------------------" >&2
    if [ -n "$POSTINST_LOG" ]; then
        echo "--------------------------------------------------------------------------------" >>"$POSTINST_LOG"
    fi
}

# Log an error and abort the install or configuration run.
die() {
    log ERROR "$@"
    exit 1
}
