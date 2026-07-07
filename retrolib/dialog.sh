# shellcheck shell=bash
# Helpers for the autoinst/dialog.sh serial plain-text adapter.

# Waits for one dialog screen and sends the answer after its RESPONSE prompt.
# Usage: dialog_answer [-r] TITLE TYPE [TEXT ...] ANSWER
dialog_answer() {
    local matcher=text_contains_line
    local usage="dialog_answer requires [-r] TITLE TYPE [TEXT ...] ANSWER"
    local title type

    if [ "${1:-}" = "-r" ]; then
        matcher=serial_contains_regex
        shift
    fi
    [ $# -ge 3 ] || die "$usage"
    title=$1
    type=$2
    shift 2

    serial_wait_one "$matcher" "TITLE: $title"
    if [ -n "$type" ]; then
        serial_wait_one text_contains_line "TYPE: $type"
    fi
    while [ $# -gt 1 ]; do
        serial_wait_one text_contains_string "TEXT: $1"
        shift
    done
    serial_wait_one text_contains_line "RESPONSE:"
    serial_send "$1"
}

# Typed wrappers for dialog_answer, one per widget.
# Usage: dialog_TYPE [-r] TITLE [TEXT ...] ANSWER
dialog_widget_answer() {
    local type args=()
    type=$1
    shift
    if [ "${1:-}" = "-r" ]; then
        args+=(-r)
        shift
    fi
    args+=("$1" "$type")
    shift
    dialog_answer "${args[@]}" "$@"
}

dialog_msgbox() { dialog_widget_answer msgbox "$@"; }
dialog_yesno() { dialog_widget_answer yesno "$@"; }
dialog_inputbox() { dialog_widget_answer inputbox "$@"; }
dialog_menu() { dialog_widget_answer menu "$@"; }
dialog_checklist() { dialog_widget_answer checklist "$@"; }
dialog_radiolist() { dialog_widget_answer radiolist "$@"; }

# Handles dialog screens in stream order; the final title is an unanswered terminator.
# Handlers receive the matched title and answer the screen themselves.
dialog_case() {
    local wait_opt=-l
    local usage="dialog_case requires [-r] [TITLE HANDLER ...] TERMINATOR"
    local terminator titles=() handlers=() answered=()
    local pending=() map=() count matched i mark

    if [ "${1:-}" = "-r" ]; then
        wait_opt=-r
        shift
    fi

    [ $(($# % 2)) -eq 1 ] || die "$usage"
    terminator=${!#}

    while [ $# -gt 1 ]; do
        titles+=("$1")
        handlers+=("$2")
        answered+=(false)
        shift 2
    done

    count=${#titles[@]}
    while :; do
        pending=("TITLE: $terminator")
        map=(0)
        for ((i = 0; i < count; i++)); do
            if [ "${answered[$i]}" = false ]; then
                pending+=("TITLE: ${titles[$i]}")
                map+=("$i")
            fi
        done
        mark=$SERIAL_LINE
        serial_wait_alternative "$wait_opt" "${pending[@]}"
        matched=$?
        # Rewind so the handler, or the caller for the terminator, can re-match.
        serial_rewind "$mark"
        if [ "$matched" -eq 0 ]; then
            return 0
        fi
        i=${map[$matched]}
        "${handlers[$i]}" "${titles[$i]}"
        answered[i]=true
    done
}

# Like dialog_case, but KEY ANSWER pairs are answered directly.
# Default keys are titles; -r is regex title matching, -s is substring matching.
dialog_answer_any() {
    local wait_opt=-l by_title=true
    local usage="dialog_answer_any requires [-r | -s] [KEY ANSWER ...] TERMINATOR"
    local terminator keys=() answers=() answered=()
    local pending=() map=() count matched i mark

    case "${1:-}" in
    -r)
        wait_opt=-r
        shift
        ;;
    -s)
        wait_opt=
        by_title=false
        shift
        ;;
    esac

    [ $(($# % 2)) -eq 1 ] || die "$usage"
    terminator=${!#}

    while [ $# -gt 1 ]; do
        keys+=("$1")
        answers+=("$2")
        answered+=(false)
        shift 2
    done

    count=${#keys[@]}
    while :; do
        if [ "$by_title" = true ]; then
            pending=("TITLE: $terminator")
        else
            pending=("$terminator")
        fi
        map=(0)
        for ((i = 0; i < count; i++)); do
            if [ "${answered[$i]}" = false ]; then
                if [ "$by_title" = true ]; then
                    pending+=("TITLE: ${keys[$i]}")
                else
                    pending+=("${keys[$i]}")
                fi
                map+=("$i")
            fi
        done
        mark=$SERIAL_LINE
        # shellcheck disable=SC2086 # wait_opt is empty in substring mode.
        serial_wait_alternative $wait_opt "${pending[@]}"
        matched=$?
        # Rewind so follow-up waits can consume the matched screen.
        serial_rewind "$mark"
        if [ "$matched" -eq 0 ]; then
            return 0
        fi
        i=${map[$matched]}
        if [ "$by_title" = false ]; then
            serial_send "${answers[$i]}"
        elif [ "$wait_opt" = -r ]; then
            dialog_answer -r "${keys[$i]}" "" "${answers[$i]}"
        else
            dialog_answer "${keys[$i]}" "" "${answers[$i]}"
        fi
        answered[i]=true
    done
}

# Accept an optional configuration screen.
dialog_yes() {
    dialog_answer "$1" yesno yes
}

# Decline an optional configuration screen.
dialog_no() {
    dialog_answer "$1" yesno no
}

# Acknowledge an informational screen.
dialog_ok() {
    dialog_answer "$1" msgbox ok
}
