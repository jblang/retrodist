# shellcheck shell=bash
# Helpers for the autoinst/dialog.sh serial plain-text adapter.

# Waits for one dialog screen and sends the answer after its RESPONSE prompt.
# An "any" TYPE skips the type check.
# Usage: dialog_expect [-r] TITLE TYPE ANSWER
dialog_expect() {
    local matcher=text_contains_line
    local usage="dialog_expect requires [-r] TITLE TYPE ANSWER"

    if [ "${1:-}" = "-r" ]; then
        matcher=serial_contains_regex
        shift
    fi
    [ $# -eq 3 ] || die "$usage"

    serial_wait_one "$matcher" "TITLE: $1"
    if [ "$2" != any ]; then
        serial_wait_one dialog_line_type_matches "$2"
    fi
    serial_prompt "RESPONSE:" "$3"
}

# Matches a TYPE line against the expected widget type.
dialog_line_type_matches() {
    case "$1" in
    TYPE:\ *) dialog_type_matches "${1#TYPE: }" "$2" ;;
    *) return 1 ;;
    esac
}

# Matches a menu ITEM line whose displayed text contains the fixed string.
dialog_item_text_matches() {
    case "$1" in
    ITEM:\ *\ ::\ *"$2"*) return 0 ;;
    *) return 1 ;;
    esac
}

# Matches a menu ITEM line whose displayed text matches the extended regex.
dialog_item_text_matches_regex() {
    case "$1" in
    ITEM:\ *\ ::\ *) serial_contains_regex "${1#* :: }" "$2" ;;
    *) return 1 ;;
    esac
}

# Tests whether two widget types match; msgbox and textbox are interchangeable.
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

# Collects into candidates the alternatives whose title patterns match the
# matched title line (dynamic scope of dialog_wait_typed_alternative).
dialog_title_candidates() {
    local i

    candidates=()
    for ((i = 0; i < ${#titles[@]}; i++)); do
        "${matchers[$i]}" "$title_line" "TITLE: ${titles[$i]}" || continue
        candidates+=("$i")
    done
}

# Sets alt to the first candidate the screen's TYPE line satisfies, dying if
# none does (dynamic scope of dialog_wait_typed_alternative).
dialog_probe_type() {
    local i type_line

    if ! serial_wait_until \
        text_contains_string "TYPE:" \
        text_contains_line "RESPONSE:" \
        -- >/dev/null; then
        for i in "${candidates[@]}"; do
            [ "${types[$i]}" = any ] || continue
            alt=$i
            return 0
        done
        die "dialog did not include a TYPE line: $title_line"
    fi
    type_line=$SERIAL_MATCHED_TEXT
    for i in "${candidates[@]}"; do
        [ "${types[$i]}" != any ] || continue
        if dialog_type_matches "${type_line#TYPE: }" "${types[$i]}"; then
            alt=$i
            return 0
        fi
    done
    die "dialog type did not match any handler: $title_line / $type_line"
}

# Waits for one of the MATCHER TYPE TITLE INDEX alternative quads and returns
# the matched INDEX, leaving the screen unconsumed for the caller to answer.
dialog_wait_typed_alternative() {
    local usage="dialog_wait_typed_alternative requires [MATCHER TYPE TITLE INDEX ...]"
    local titles=() types=() indexes=() matchers=() pairs=() candidates=()
    local mark title_line alt

    [ $# -gt 0 ] || die "$usage"
    [ $(($# % 4)) -eq 0 ] || die "$usage"
    while [ $# -gt 0 ]; do
        [ -n "$2" ] || die "$usage"
        matchers+=("$1")
        types+=("$2")
        titles+=("$3")
        indexes+=("$4")
        pairs+=("$1" "TITLE: $3")
        shift 4
    done

    mark=$SERIAL_LINE
    serial_wait_until "${pairs[@]}" -- >/dev/null
    title_line=$SERIAL_MATCHED_TEXT
    dialog_title_candidates
    dialog_probe_type
    serial_rewind "$mark"
    return "${indexes[$alt]}"
}

# Answers parsed alternative I (dynamic scope of dialog_answer).
dialog_answer_alt() {
    local i=$1

    if [ "${modes[$i]}" = func ]; then
        "${answers[$i]}" "${keys[$i]}"
    elif [ "${modes[$i]}" = desc ]; then
        dialog_answer_desc "$i"
    elif [ "${matchers[$i]}" = serial_contains_regex ]; then
        dialog_expect -r "${keys[$i]}" "${types[$i]}" "${answers[$i]}"
    else
        dialog_expect "${keys[$i]}" "${types[$i]}" "${answers[$i]}"
    fi
}

# Answers menu alternative I by sending the key of the item whose displayed
# text matches the description (dynamic scope of dialog_answer).
dialog_answer_desc() {
    local i=$1 item_key

    serial_wait_one "${matchers[$i]}" "TITLE: ${keys[$i]}"
    if [ "${types[$i]}" != any ]; then
        serial_wait_one dialog_line_type_matches "${types[$i]}"
    fi
    serial_wait_until \
        "${item_matchers[$i]}" "${answers[$i]}" \
        text_contains_line "RESPONSE:" \
        -- >/dev/null || die "dialog_answer did not find item text: ${answers[$i]}"
    item_key=${SERIAL_MATCHED_TEXT#ITEM: }
    item_key=${item_key%% :: *}
    serial_prompt "RESPONSE:" "$item_key"
}

# Parses the alternative triples and optional trailing terminator pair into
# dialog_answer's arrays and terminator variables (dynamic scope).
dialog_answer_parse() {
    local key type answer mode matcher item_matcher terminate_next

    while [ $# -gt 0 ]; do
        terminate_next=false
        if [ "$1" = "-x" ]; then
            terminate_next=true
            shift
        elif [ $# -eq 2 ] || { [ $# -eq 3 ] && [ "$2" = "-r" ]; }; then
            terminator_type=$1
            [ -n "$terminator_type" ] || die "$usage"
            shift
            if [ "$1" = "-r" ]; then
                terminator_matcher=serial_contains_regex
                shift
            fi
            terminator=$1
            shift
            continue
        fi
        [ $# -ge 3 ] || die "$usage"
        type=$1
        [ -n "$type" ] || die "$usage"
        shift
        matcher=text_contains_line
        if [ "$1" = "-r" ]; then
            matcher=serial_contains_regex
            shift
        fi
        key=$1
        shift
        mode=answer
        item_matcher=''
        if [ "${1:-}" = "-f" ]; then
            mode=func
            shift
        elif [ "${1:-}" = "-d" ]; then
            mode=desc
            item_matcher=dialog_item_text_matches
            shift
            if [ "${1:-}" = "-r" ]; then
                item_matcher=dialog_item_text_matches_regex
                shift
            fi
        fi
        [ $# -ge 1 ] || die "$usage"
        answer=$1
        shift
        types+=("$type")
        matchers+=("$matcher")
        keys+=("$key")
        modes+=("$mode")
        item_matchers+=("$item_matcher")
        answers+=("$answer")
        answered+=(false)
        terminal+=("$terminate_next")
    done
}

# Rebuilds the pending quads from the terminator and the unanswered
# alternatives (dynamic scope of dialog_answer).
dialog_answer_pending() {
    local i

    pending=()
    if [ -n "$terminator" ]; then
        pending+=("$terminator_matcher" "$terminator_type" "$terminator" 255)
    fi
    for ((i = 0; i < count; i++)); do
        [ "${answered[$i]}" = false ] || continue
        pending+=("${matchers[$i]}" "${types[$i]}" "${keys[$i]}" "$i")
    done
}

# Answers dialog screens in stream order, given TYPE TITLE ANSWER alternatives:
#   ANSWER is the answer to send; a single triple answers its screen directly
#   -f ANSWER is a handler function called with the matched TITLE
#   -d ANSWER matches on menu item description and sends the matching key
#   -r before a TITLE or description matches it as an extended regex
#   -x before a triple answers that screen and then returns
#   a trailing TYPE [-r] TITLE pair is matched, left unanswered, and exits
#   -l LABEL logs entry and exit; without it nothing is logged
# Usage: dialog_answer [-l LABEL] [-x] TYPE [-r] TITLE [-f | -d [-r]] ANSWER \
#        [...] [TERMINATOR_TYPE [-r] TERMINATOR]
dialog_answer() {
    local usage="dialog_answer requires [-l LABEL] [-x] TYPE [-r] TITLE [-f | -d [-r]] ANSWER ... [TERMINATOR_TYPE [-r] TERMINATOR]"
    local label=''
    local terminator='' terminator_type='' terminator_matcher=text_contains_line
    local keys=() types=() answers=() modes=() matchers=() item_matchers=() answered=() terminal=()
    local pending=() count i

    if [ "${1:-}" = "-l" ]; then
        [ $# -ge 2 ] || die "$usage"
        label=$2
        shift 2
    fi
    dialog_answer_parse "$@"
    count=${#keys[@]}
    [ "$count" -gt 0 ] || die "$usage"

    # A lone triple needs no alternative dispatch; match the screen directly.
    if [ "$count" -eq 1 ] && [ -z "$terminator" ]; then
        dialog_answer_alt 0
        return
    fi

    [ -n "$terminator" ] || [[ " ${terminal[*]} " = *" true "* ]] || die "$usage"

    [ -z "$label" ] || log_write "🔀" "Answering $label questions with $count alternatives"
    while :; do
        dialog_answer_pending
        dialog_wait_typed_alternative "${pending[@]}"
        i=$?
        if [ "$i" -eq 255 ]; then
            [ -z "$label" ] || log_write "🔀" "Exiting $label questions leaving \"$terminator\" unanswered"
            return 0
        fi
        dialog_answer_alt "$i"
        answered[i]=true
        if [ "${terminal[$i]}" = true ]; then
            [ -z "$label" ] || log_write "🔀" "Exiting $label questions after answering \"${keys[$i]}\""
            return 0
        fi
    done
}
