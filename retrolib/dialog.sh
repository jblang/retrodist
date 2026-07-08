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
        serial_wait_one dialog_line_type_matches "$type"
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

dialog_line_type_matches() {
    local line expected
    line=$1
    expected=$2

    case "$line" in
    TYPE:\ *)
        dialog_type_matches "${line#TYPE: }" "$expected"
        ;;
    *)
        return 1
        ;;
    esac
}

dialog_item_text_matches() {
    local line pattern item_text
    line=$1
    pattern=$2

    case "$line" in
    ITEM:\ *\ ::\ *)
        item_text=${line#* :: }
        ;;
    *)
        return 1
        ;;
    esac
    text_contains_string "$item_text" "$pattern"
}

dialog_item_text_matches_regex() {
    local line pattern item_text
    line=$1
    pattern=$2

    case "$line" in
    ITEM:\ *\ ::\ *)
        item_text=${line#* :: }
        ;;
    *)
        return 1
        ;;
    esac
    serial_contains_regex "$item_text" "$pattern"
}

# Selects a menu item by matching its displayed item text and sending its key.
# Usage: dialog_menu_text [-r] TITLE ITEM_TEXT
dialog_menu_text() {
    local matcher=dialog_item_text_matches
    local usage="dialog_menu_text requires [-r] TITLE ITEM_TEXT"
    local title item_text item_line item_key

    if [ "${1:-}" = "-r" ]; then
        matcher=dialog_item_text_matches_regex
        shift
    fi
    [ $# -eq 2 ] || die "$usage"
    title=$1
    item_text=$2

    serial_wait_one text_contains_line "TITLE: $title"
    serial_wait_one text_contains_line "TYPE: menu"
    while :; do
        serial_wait_until \
            "$matcher" "$item_text" \
            text_contains_line "RESPONSE:" \
            -- >/dev/null
        case $? in
        0)
            item_line=$SERIAL_MATCHED_TEXT
            item_key=${item_line#ITEM: }
            item_key=${item_key%% :: *}
            serial_wait_one text_contains_line "RESPONSE:"
            serial_send "$item_key"
            return 0
            ;;
        1)
            die "dialog_menu_text did not find item text: $item_text"
            ;;
        esac
    done
}

dialog_type_matches() {
    local actual expected
    actual=$1
    expected=$2

    [ "$actual" = "$expected" ] && return 0
    case "$actual:$expected" in
    msgbox:textbox | textbox:msgbox)
        return 0
        ;;
    esac
    return 1
}

# Waits for one of the requested dialog type/title alternatives.
dialog_wait_typed_alternative() {
    local wait_opt=$1
    shift
    local usage="dialog_wait_typed_alternative requires WAIT_OPT [TYPE TITLE INDEX ...]"
    local titles=() types=() indexes=() pending=() candidates=()
    local count i mark title_line type_line type_status type title

    [ $(($# % 3)) -eq 0 ] || die "$usage"
    [ $# -gt 0 ] || die "$usage"
    while [ $# -gt 0 ]; do
        type=$1
        title=$2
        [ -n "$type" ] || die "$usage"
        types+=("$type")
        titles+=("$title")
        indexes+=("$3")
        pending+=("TITLE: $title")
        shift 3
    done

    count=${#titles[@]}
    while :; do
        mark=$SERIAL_LINE
        serial_wait_alternative "$wait_opt" "${pending[@]}" >/dev/null
        title_line=$SERIAL_MATCHED_TEXT

        candidates=()
        for ((i = 0; i < count; i++)); do
            if [ "$wait_opt" = -r ]; then
                serial_contains_regex "$title_line" "TITLE: ${titles[$i]}" || continue
            else
                text_contains_line "$title_line" "TITLE: ${titles[$i]}" || continue
            fi
            candidates+=("$i")
        done

        serial_wait_until \
            text_contains_string "TYPE:" \
            text_contains_line "RESPONSE:" \
            -- >/dev/null
        type_status=$?
        type_line=$SERIAL_MATCHED_TEXT
        if [ "$type_status" -ne 0 ]; then
            for i in "${candidates[@]}"; do
                if [ "${types[$i]}" = any ]; then
                    serial_rewind "$mark"
                    return "${indexes[$i]}"
                fi
            done
            die "dialog did not include a TYPE line: $title_line"
        fi

        for i in "${candidates[@]}"; do
            [ "${types[$i]}" != any ] || continue
            if dialog_type_matches "${type_line#TYPE: }" "${types[$i]}"; then
                serial_rewind "$mark"
                return "${indexes[$i]}"
            fi
        done
        die "dialog type did not match any handler: $title_line / $type_line"
    done
}

# Logs dispatch entry with each alternative and its return number.
dialog_log_alts() {
    local func=$1 alt
    shift
    log_write "🔀" "Entering $func with $# alternatives:"
    for alt in "$@"; do
        log_write "🔀" "$alt"
    done
}

# Handles dialog screens in stream order; the final type/title is an unanswered
# terminator. Handlers receive the matched title and answer the screen
# themselves. Prefix a TYPE TITLE HANDLER triple with -t to answer it and then
# return.
dialog_case() {
    local wait_opt=-l
    local usage="dialog_case requires [-r] [TYPE TITLE HANDLER ...] [-t TYPE TITLE HANDLER] [TERMINATOR_TYPE TERMINATOR]"
    local terminate_next=false terminator='' terminator_type=''
    local titles=() types=() handlers=() answered=() terminal=()
    local pending=() alts=() count i matched title type handler

    if [ "${1:-}" = "-r" ]; then
        wait_opt=-r
        shift
    fi

    while [ $# -gt 0 ]; do
        if [ "$1" = "-t" ]; then
            terminate_next=true
            shift
            [ $# -ge 3 ] || die "$usage"
        elif [ $# -eq 2 ]; then
            [ "$terminate_next" = false ] || die "$usage"
            terminator_type=$1
            terminator=$2
            [ -n "$terminator_type" ] || die "$usage"
            shift 2
            continue
        elif [ $# -lt 3 ]; then
            die "$usage"
        fi

        type=$1
        title=$2
        handler=$3
        shift 3
        [ -n "$type" ] || die "$usage"
        titles+=("$title")
        types+=("$type")
        handlers+=("$handler")
        answered+=(false)
        terminal+=("$terminate_next")
        terminate_next=false
    done
    [ -n "$terminator" ] || {
        for i in "${terminal[@]}"; do
            [ "$i" = true ] && break
        done
        [ "${i:-}" = true ] || die "$usage"
    }

    count=${#titles[@]}
    for ((i = 0; i < count; i++)); do
        alts+=("$i: ${types[$i]} \"${titles[$i]}\" -> ${handlers[$i]}")
    done
    [ -z "$terminator" ] || alts+=("255: $terminator_type \"$terminator\" (terminator)")
    dialog_log_alts dialog_case "${alts[@]}"
    while :; do
        pending=()
        if [ -n "$terminator" ]; then
            pending+=("$terminator_type" "$terminator" 255)
        fi
        for ((i = 0; i < count; i++)); do
            if [ "${answered[$i]}" = false ]; then
                pending+=("${types[$i]}" "${titles[$i]}" "$i")
            fi
        done
        dialog_wait_typed_alternative "$wait_opt" "${pending[@]}"
        matched=$?
        if [ "$matched" -eq 255 ]; then
            log_write "🔀" "Exiting dialog_case with terminator \"$terminator\""
            return 0
        fi
        "${handlers[$matched]}" "${titles[$matched]}"
        answered[matched]=true
        if [ "${terminal[$matched]}" = true ]; then
            log_write "🔀" "Exiting dialog_case with terminal alternative $matched \"${titles[$matched]}\""
            return 0
        fi
    done
}

# Like dialog_case, but TYPE KEY ANSWER triples are answered directly.
# Default keys are titles; -r is regex title matching, -s is substring matching.
# Prefix a TYPE KEY ANSWER triple with -t to answer it and then return.
dialog_answer_any() {
    local wait_opt=-l by_title=true
    local usage="dialog_answer_any requires [-r | -s] [TYPE KEY ANSWER ...] [-t TYPE KEY ANSWER] [TERMINATOR_TYPE TERMINATOR]"
    local terminate_next=false terminator='' terminator_type=''
    local keys=() types=() answers=() answered=() terminal=()
    local pending=() alts=() count matched i mark key type answer

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

    while [ $# -gt 0 ]; do
        if [ "$1" = "-t" ]; then
            terminate_next=true
            shift
            [ $# -ge 3 ] || die "$usage"
        elif [ $# -eq 2 ]; then
            [ "$terminate_next" = false ] || die "$usage"
            terminator_type=$1
            terminator=$2
            [ -n "$terminator_type" ] || die "$usage"
            shift 2
            continue
        elif [ $# -lt 3 ]; then
            die "$usage"
        fi

        type=$1
        key=$2
        answer=$3
        shift 3
        [ -n "$type" ] || die "$usage"
        if [ "$by_title" = false ] && [ "$type" != any ]; then
            die "dialog_answer_any -s requires type any"
        fi
        keys+=("$key")
        types+=("$type")
        answers+=("$answer")
        answered+=(false)
        terminal+=("$terminate_next")
        terminate_next=false
    done
    [ -n "$terminator" ] || {
        for i in "${terminal[@]}"; do
            [ "$i" = true ] && break
        done
        [ "${i:-}" = true ] || die "$usage"
    }

    count=${#keys[@]}
    for ((i = 0; i < count; i++)); do
        alts+=("$i: ${types[$i]} \"${keys[$i]}\" -> \"${answers[$i]}\"")
    done
    if [ -n "$terminator" ]; then
        if [ "$by_title" = true ]; then
            alts+=("255: $terminator_type \"$terminator\" (terminator)")
        else
            alts+=("terminator: \"$terminator\"")
        fi
    fi
    dialog_log_alts dialog_answer_any "${alts[@]}"
    while :; do
        pending=()
        map=()
        if [ -n "$terminator" ]; then
            if [ "$by_title" = true ]; then
                pending+=("$terminator_type" "$terminator" 255)
            else
                pending+=("$terminator")
                map+=(-1)
            fi
        fi
        for ((i = 0; i < count; i++)); do
            if [ "${answered[$i]}" = false ]; then
                if [ "$by_title" = true ]; then
                    pending+=("${types[$i]}" "${keys[$i]}" "$i")
                else
                    pending+=("${keys[$i]}")
                    map+=("$i")
                fi
            fi
        done
        if [ "$by_title" = true ]; then
            dialog_wait_typed_alternative "$wait_opt" "${pending[@]}"
            i=$?
            if [ "$i" -eq 255 ]; then
                log_write "🔀" "Exiting dialog_answer_any with terminator \"$terminator\""
                return 0
            fi
        else
            mark=$SERIAL_LINE
            serial_wait_alternative "${pending[@]}"
            matched=$?
            serial_rewind "$mark"
            i=${map[$matched]}
            if [ "$i" -eq -1 ]; then
                log_write "🔀" "Exiting dialog_answer_any with terminator \"$terminator\""
                return 0
            fi
        fi
        if [ "$by_title" = false ]; then
            serial_send "${answers[$i]}"
        elif [ "$wait_opt" = -r ]; then
            if [ "${types[$i]}" = any ]; then
                dialog_answer -r "${keys[$i]}" "" "${answers[$i]}"
            else
                dialog_answer -r "${keys[$i]}" "${types[$i]}" "${answers[$i]}"
            fi
        else
            if [ "${types[$i]}" = any ]; then
                dialog_answer "${keys[$i]}" "" "${answers[$i]}"
            else
                dialog_answer "${keys[$i]}" "${types[$i]}" "${answers[$i]}"
            fi
        fi
        answered[i]=true
        if [ "${terminal[$i]}" = true ]; then
            log_write "🔀" "Exiting dialog_answer_any with terminal alternative $i \"${keys[$i]}\""
            return 0
        fi
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
