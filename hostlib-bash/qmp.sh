# shellcheck shell=bash
# QMP control-channel helpers.

# Sets default QMP connection settings.
qmp_set_defaults() {
    QEMU_QMP_PIPE=${QEMU_QMP_PIPE:-qmp}
    QMP_TIMEOUT=${QMP_TIMEOUT:-1}
}

# Verifies commands and files required by the QMP control channel.
qmp_check_prereqs() {
    log_debug "Checking QMP helper prerequisites"
    if ! command -v jq >/dev/null 2>&1; then
        log_error "Missing jq in PATH"
        return 1
    fi
    qmp_require_pipe
}

# Resolves the configured QMP pipe name to a client-side path.
qmp_pipe_candidate_path() {
    case "$QEMU_QMP_PIPE" in
    /* | none) printf '%s\n' "$QEMU_QMP_PIPE" ;;
    *)
        if [[ "$QEMU_QMP_PIPE" == */* ]]; then
            printf '%s\n' "$QEMU_QMP_PIPE"
        elif [ -d qemu.d ]; then
            printf 'qemu.d/%s\n' "$QEMU_QMP_PIPE"
        else
            printf '%s\n' "$QEMU_QMP_PIPE"
        fi
        ;;
    esac
}

# Tests whether the current directory is the default QEMU work directory.
qmp_pipe_dir_is_default() {
    [[ ${PWD##*/} == qemu.d || (-n "${QEMU_D:-}" && $PWD == "$QEMU_D") ]]
}

# Tests whether the default pipe name cannot be resolved from this directory.
qmp_default_pipe_is_ambiguous() {
    local pipe=$1

    [ "$QEMU_QMP_PIPE" = qmp ] || return 1
    [ ! -d qemu.d ] || return 1
    if qmp_pipe_dir_is_default; then
        return 1
    fi
    [ ! -p "$pipe.in" ] || [ ! -p "$pipe.out" ]
}

# Resolves the configured QMP pipe and rejects ambiguous default locations.
qmp_pipe_path() {
    local pipe

    pipe=$(qmp_pipe_candidate_path) || return 1
    if qmp_default_pipe_is_ambiguous "$pipe"; then
        log_error "Could not identify QMP pipe. Run qmp-bash from a distro config directory with qemu.d/qmp.in, from inside qemu.d, or pass -s PIPE."
        return 1
    fi
    printf '%s\n' "$pipe"
}

# Prints the directory QEMU uses for relative HMP file paths.
qmp_hmp_file_dir() {
    local pipe

    pipe=$(qmp_pipe_path) || return 1
    dirname "$pipe"
}

# Verifies the configured QMP FIFO pair exists.
qmp_require_pipe() {
    local pipe

    if [ "$QEMU_QMP_PIPE" = "none" ]; then
        log_error "QMP pipe is disabled"
        return 1
    fi
    pipe=$(qmp_pipe_path) || return 1
    if { [ ! -p "$pipe.in" ] || [ ! -p "$pipe.out" ]; } && [ "${QMP_TIMEOUT:-0}" != "0" ]; then
        log_debug "Waiting up to $QMP_TIMEOUT second(s) for QMP pipe $pipe"
        sleep "$QMP_TIMEOUT"
    fi
    if [ ! -p "$pipe.in" ] || [ ! -p "$pipe.out" ]; then
        log_error "QMP pipe does not exist: $pipe"
        return 1
    fi
}

# Holds both QMP FIFOs open on file descriptors 6 and 7.
qmp_pipe_open() {
    local pipe

    if [ "${QEMU_QMP_PIPE:-none}" = "none" ]; then
        return 0
    fi
    pipe=$(qmp_pipe_path) || return 1
    QMP_LOG=${QMP_LOG:-$pipe.log}
    exec 6<>"$pipe.in" || return 1
    if ! exec 7<>"$pipe.out"; then
        exec 6>&-
        return 1
    fi
    QMP_PIPE_OPEN=1
}

# Closes the QMP FIFO file descriptors held by this process.
qmp_pipe_close() {
    if [ "${QMP_PIPE_OPEN:-0}" = "1" ]; then
        exec 6>&-
        exec 7>&-
        QMP_PIPE_OPEN=0
    fi
}

# Acquires exclusive access to the shared QMP response stream.
qmp_lock_acquire() {
    local attempt=0 pipe lock

    if [ "${QMP_LOCK_HELD:-0}" = "1" ]; then
        return 0
    fi
    pipe=$(qmp_pipe_path) || return 1
    lock=$pipe.lock
    while ! mkdir "$lock" 2>/dev/null; do
        attempt=$((attempt + 1))
        if [ "$attempt" -ge 100 ]; then
            log_error "Timed out waiting for QMP lock $lock"
            return 1
        fi
        sleep 0.01
    done
    QMP_LOCK_DIR=$lock
    QMP_LOCK_HELD=1
}

# Releases this process's exclusive access to the QMP stream.
qmp_lock_release() {
    if [ "${QMP_LOCK_HELD:-0}" = "1" ]; then
        rmdir "$QMP_LOCK_DIR" 2>/dev/null || true
        QMP_LOCK_HELD=0
    fi
}

# Truncates the transaction log for a newly started QEMU session.
qmp_log_reset() {
    [ "${QMP_LOG:-none}" = none ] || : >"$QMP_LOG"
}

# Appends one raw QMP protocol line.
qmp_log_line() {
    [ "${QMP_LOG:-none}" = none ] || printf '%s\n' "$1" >>"$QMP_LOG"
}

# Writes and logs one raw QMP request.
qmp_write_request() {
    qmp_log_line "$1" || return 1
    printf '%s\n' "$1" >&6
}

# Reads QMP lines until the response with the requested ID arrives.
qmp_read_response() {
    local id=$1 line parsed

    while IFS= read -r -t "$QMP_TIMEOUT" line <&7; do
        qmp_log_line "$line" || return 1
        parsed=$(jq -r --arg id "$id" '
            if type == "object" and .id? == $id then
                if has("error") then "error" + (.error | tojson)
                else "return" + (if (.return | type) == "string" then .return else (.return | tojson) end)
                end
            else empty
            end
        ' <<<"$line") || {
            log_error "Invalid QMP response: $line"
            return 1
        }
        if [ -n "$parsed" ]; then
            QMP_RESPONSE=$parsed
            return 0
        fi
    done
    log_error "Timed out waiting for QMP response $id"
    return 1
}

# Sends one request and reads its matching response while holding the QMP lock.
qmp_execute_request() {
    local request=$1 id=$2 lock_owner=0 status=0

    if [ "${QMP_LOCK_HELD:-0}" != "1" ]; then
        qmp_lock_acquire || return 1
        lock_owner=1
    fi
    qmp_write_request "$request" || status=1
    if [ "$status" -eq 0 ]; then
        qmp_read_response "$id" || status=1
    fi
    [ "$lock_owner" -eq 0 ] || qmp_lock_release
    return "$status"
}

# Negotiates QMP capabilities once for a newly started QEMU process.
qmp_negotiate_capabilities() {
    local id="capabilities-$$" request status=0

    if [ "${QEMU_QMP_PIPE:-none}" = "none" ]; then
        return 0
    fi
    printf -v request '{"execute":"qmp_capabilities","id":"%s"}' "$id"
    qmp_execute_request "$request" "$id" || status=1
    if [ "$status" -eq 0 ]; then
        case "$QMP_RESPONSE" in
        return*) ;;
        error*'"class":"CommandNotFound"'*'Capabilities negotiation is already complete'*) ;;
        error*) printf '%s\n' "${QMP_RESPONSE#error}" >&2; status=1 ;;
        *) status=1 ;;
        esac
    fi
    return "$status"
}

# Initializes and negotiates the QMP control channel.
qmp_init() {
    log_info "Initializing QMP control channel"
    qmp_set_defaults
    qmp_check_prereqs || return 1
    qmp_negotiate_capabilities
}

# Tests whether the QEMU process for this install is still running.
qmp_vm_is_running() {
    local state

    [ -n "${QEMU_PID:-}" ] || return 0
    state=$(ps -p "$QEMU_PID" -o stat= 2>/dev/null) || return 1
    [[ $state != Z* ]]
}

# Sends one HMP command and stores its plain-text response.
qmp_execute_hmp() {
    local command=${1:-} id request status=0

    if [ -z "$command" ]; then
        log_error "Missing QMP HMP command"
        return 1
    fi
    id="hmp-$$-$RANDOM"
    log_debug "Sending QMP HMP command: $command"
    request=$(jq -nc --arg command "$command" --arg id "$id" \
        '{execute:"human-monitor-command",arguments:{"command-line":$command},id:$id}') || status=1
    if [ "$status" -eq 0 ]; then
        qmp_execute_request "$request" "$id" || status=1
    fi
    if [ "$status" -eq 0 ]; then
        case "$QMP_RESPONSE" in
        error*) printf '%s\n' "${QMP_RESPONSE#error}" >&2; status=1 ;;
        *) QMP_HMP_RESPONSE=${QMP_RESPONSE#return} ;;
        esac
    fi
    return "$status"
}

# Sends HMP commands and prints their non-empty responses in order.
qmp_hmp_commands() {
    local command

    if [ $# -eq 0 ]; then
        log_error "qmp_hmp_commands requires COMMAND [COMMAND ...]"
        return 1
    fi

    for command in "$@"; do
        qmp_execute_hmp "$command" || return 1
        [ -z "$QMP_HMP_RESPONSE" ] || printf '%s\n' "$QMP_HMP_RESPONSE"
    done
}
