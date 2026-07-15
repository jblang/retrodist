# shellcheck shell=bash
# Helpers for the guestlib/dialog.sh serial plain-text adapter.

DIALOG_NO_REQUIRED_ITEM=__retro_dialog_no_required_item__

# Waits for one dialog screen and sends the answer after its RESPONSE prompt.
# An "any" TYPE skips the type check.
# Usage: dialog_expect [-r] TITLE TYPE ANSWER
dialog_expect() {
    local matcher=text_contains_line
    local usage="dialog_expect requires [-r] TITLE TYPE ANSWER"

    if [ "${1:-}" = "-r" ]; then
        matcher=text_contains_regex
        shift
    fi
    [ $# -eq 3 ] || die "$usage"

    serial_wait_match "$matcher" "TITLE: $1"
    if [ "$2" != any ]; then
        serial_wait_match dialog_line_type_matches "$2"
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
    ITEM:\ *\ ::\ *) text_contains_regex "${1#* :: }" "$2" ;;
    *) return 1 ;;
    esac
}

# Matches a menu ITEM line whose key and displayed text contain the string.
dialog_item_matches() {
    case "$1" in
    ITEM:\ *"$2"*) return 0 ;;
    *) return 1 ;;
    esac
}

# Matches a menu ITEM line whose key and displayed text match the extended regex.
dialog_item_matches_regex() {
    case "$1" in
    ITEM:\ *) text_contains_regex "${1#ITEM: }" "$2" ;;
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
# matched title line (dynamic scope of dialog_wait_alternative).
dialog_collect_title_candidates() {
    local i

    candidates=()
    for ((i = 0; i < ${#titles[@]}; i++)); do
        "${matchers[$i]}" "$title_line" "TITLE: ${titles[$i]}" || continue
        candidates+=("$i")
    done
}

# Filters candidates to the alternatives the screen's TYPE line satisfies,
# dying if none do (dynamic scope of dialog_wait_alternative).
dialog_filter_type_candidates() {
    local i type_line
    local typed_candidates=()

    if ! serial_wait_until \
        text_contains_string "TYPE:" \
        text_contains_line "RESPONSE:" \
        -- >/dev/null; then
        for i in "${candidates[@]}"; do
            [ "${types[$i]}" = any ] || continue
            typed_candidates+=("$i")
        done
        [ "${#typed_candidates[@]}" -gt 0 ] ||
            die "dialog did not include a TYPE line: $title_line"
        candidates=("${typed_candidates[@]}")
        return 0
    fi
    type_line=$SERIAL_MATCHED_TEXT
    for i in "${candidates[@]}"; do
        if [ "${types[$i]}" = any ] || dialog_type_matches "${type_line#TYPE: }" "${types[$i]}"; then
            typed_candidates+=("$i")
        fi
    done
    [ "${#typed_candidates[@]}" -gt 0 ] ||
        die "dialog type did not match any handler: $title_line / $type_line"
    candidates=("${typed_candidates[@]}")
}

# Selects the first candidate whose required menu item appears. If no
# candidate has an item requirement, the first type-matched candidate wins
# (dynamic scope of dialog_wait_alternative).
dialog_select_required_item_candidate() {
    local i matched fallback=
    local pairs=() pair_indexes=()

    for i in "${candidates[@]}"; do
        if [ "${required_items[$i]}" != "$DIALOG_NO_REQUIRED_ITEM" ]; then
            pairs+=("${required_item_matchers[$i]}" "${required_items[$i]}")
            pair_indexes+=("$i")
        elif [ -z "$fallback" ]; then
            fallback=$i
        fi
    done
    if [ "${#pairs[@]}" -eq 0 ]; then
        alt=${candidates[0]}
        return 0
    fi

    pairs+=(text_contains_line "RESPONSE:")
    serial_wait_until "${pairs[@]}" -- >/dev/null
    matched=$SERIAL_MATCHED
    if [ "$matched" -lt "${#pair_indexes[@]}" ]; then
        alt=${pair_indexes[$matched]}
        return 0
    fi
    if [ -n "$fallback" ]; then
        alt=$fallback
        return 0
    fi
    die "dialog did not include a required item: $title_line"
}

# Waits for one of the MATCHER TYPE TITLE REQUIRED_ITEM_MATCHER REQUIRED_ITEM
# INDEX alternatives and returns the matched INDEX, leaving the screen
# unconsumed for the caller to answer.
dialog_wait_alternative() {
    local usage="dialog_wait_alternative requires [MATCHER TYPE TITLE REQUIRED_ITEM_MATCHER REQUIRED_ITEM INDEX ...]"
    local titles=() types=() indexes=() matchers=() required_item_matchers=() required_items=() pairs=() candidates=()
    local mark title_line alt

    [ $# -gt 0 ] || die "$usage"
    [ $(($# % 6)) -eq 0 ] || die "$usage"
    while [ $# -gt 0 ]; do
        [ -n "$2" ] || die "$usage"
        matchers+=("$1")
        types+=("$2")
        titles+=("$3")
        required_item_matchers+=("$4")
        required_items+=("$5")
        indexes+=("$6")
        pairs+=("$1" "TITLE: $3")
        shift 6
    done

    mark=$SERIAL_MATCH_OFFSET
    serial_wait_until "${pairs[@]}" -- >/dev/null
    title_line=$SERIAL_MATCHED_TEXT
    dialog_collect_title_candidates
    dialog_filter_type_candidates
    dialog_select_required_item_candidate
    serial_rewind "$mark"
    return "${indexes[$alt]}"
}

# Answers parsed alternative I (dynamic scope of dialog_answer).
dialog_answer_alternative() {
    local i=$1

    if [ "${modes[$i]}" = none ]; then
        :
    elif [ "${modes[$i]}" = func ]; then
        "${answers[$i]}" "${keys[$i]}"
    elif [ "${modes[$i]}" = desc ]; then
        dialog_answer_description "$i"
    elif [ "${matchers[$i]}" = text_contains_regex ]; then
        dialog_expect -r "${keys[$i]}" "${types[$i]}" "${answers[$i]}"
    else
        dialog_expect "${keys[$i]}" "${types[$i]}" "${answers[$i]}"
    fi
}

# Answers menu alternative I by sending the key of the item whose displayed
# text matches the description (dynamic scope of dialog_answer).
dialog_answer_description() {
    local i=$1 item_key

    serial_wait_match "${matchers[$i]}" "TITLE: ${keys[$i]}"
    if [ "${types[$i]}" != any ]; then
        serial_wait_match dialog_line_type_matches "${types[$i]}"
    fi
    serial_wait_until \
        "${item_matchers[$i]}" "${answers[$i]}" \
        text_contains_line "RESPONSE:" \
        -- >/dev/null || die "dialog_answer did not find item text: ${answers[$i]}"
    item_key=${SERIAL_MATCHED_TEXT#ITEM: }
    item_key=${item_key%% :: *}
    serial_prompt "RESPONSE:" "$item_key"
}

# Parses an optional required-item clause for one alternative. Parser state
# and result variables are dynamically scoped by dialog_parse_alternative.
dialog_parse_required_item() {
    required_item_matcher=:
    required_item=$DIALOG_NO_REQUIRED_ITEM
    [ "${dialog_args[$dialog_cursor]:-}" = -i ] || return 0

    dialog_cursor=$((dialog_cursor + 1))
    required_item_matcher=dialog_item_matches
    if [ "${dialog_args[$dialog_cursor]:-}" = -r ]; then
        required_item_matcher=dialog_item_matches_regex
        dialog_cursor=$((dialog_cursor + 1))
    fi
    [ "$dialog_cursor" -lt "${#dialog_args[@]}" ] || die "$usage"
    required_item=${dialog_args[$dialog_cursor]}
    dialog_cursor=$((dialog_cursor + 1))
}

# Parses the answer mode and value for one alternative.
dialog_parse_answer() {
    mode=answer
    item_matcher=''
    case "${dialog_args[$dialog_cursor]:-}" in
    -n)
        mode=none
        answer=''
        dialog_cursor=$((dialog_cursor + 1))
        ;;
    -f)
        mode=func
        dialog_cursor=$((dialog_cursor + 1))
        [ "$dialog_cursor" -lt "${#dialog_args[@]}" ] || die "$usage"
        answer=${dialog_args[$dialog_cursor]}
        dialog_cursor=$((dialog_cursor + 1))
        ;;
    -d)
        mode=desc
        item_matcher=dialog_item_text_matches
        dialog_cursor=$((dialog_cursor + 1))
        if [ "${dialog_args[$dialog_cursor]:-}" = -r ]; then
            item_matcher=dialog_item_text_matches_regex
            dialog_cursor=$((dialog_cursor + 1))
        fi
        [ "$dialog_cursor" -lt "${#dialog_args[@]}" ] || die "$usage"
        answer=${dialog_args[$dialog_cursor]}
        dialog_cursor=$((dialog_cursor + 1))
        ;;
    *)
        [ "$dialog_cursor" -lt "${#dialog_args[@]}" ] || die "$usage"
        answer=${dialog_args[$dialog_cursor]}
        dialog_cursor=$((dialog_cursor + 1))
        ;;
    esac
}

# Parses and appends one dialog alternative.
dialog_parse_alternative() {
    local key type answer mode matcher item_matcher required_item_matcher required_item
    local terminate_next=false

    if [ "${dialog_args[$dialog_cursor]:-}" = -x ]; then
        terminate_next=true
        dialog_cursor=$((dialog_cursor + 1))
    fi
    [ "$dialog_cursor" -lt "${#dialog_args[@]}" ] || die "$usage"
    type=${dialog_args[$dialog_cursor]}
    [ -n "$type" ] || die "$usage"
    dialog_cursor=$((dialog_cursor + 1))

    matcher=text_contains_line
    if [ "${dialog_args[$dialog_cursor]:-}" = -r ]; then
        matcher=text_contains_regex
        dialog_cursor=$((dialog_cursor + 1))
    fi
    [ "$dialog_cursor" -lt "${#dialog_args[@]}" ] || die "$usage"
    key=${dialog_args[$dialog_cursor]}
    dialog_cursor=$((dialog_cursor + 1))

    dialog_parse_required_item
    dialog_parse_answer
    types+=("$type")
    matchers+=("$matcher")
    keys+=("$key")
    modes+=("$mode")
    item_matchers+=("$item_matcher")
    required_item_matchers+=("$required_item_matcher")
    required_items+=("$required_item")
    answers+=("$answer")
    answered+=(false)
    terminal+=("$terminate_next")
}

# Parses alternatives into dialog_answer's arrays (dynamic scope).
dialog_parse_alternatives() {
    local dialog_args=("$@") dialog_cursor=0

    while [ "$dialog_cursor" -lt "${#dialog_args[@]}" ]; do
        dialog_parse_alternative
    done
}

# Rebuilds the pending quads from the unanswered alternatives (dynamic scope
# of dialog_answer).
dialog_build_pending_alternatives() {
    local i

    pending=()
    for ((i = 0; i < count; i++)); do
        [ "${answered[$i]}" = false ] || continue
        pending+=("${matchers[$i]}" "${types[$i]}" "${keys[$i]}" "${required_item_matchers[$i]}" "${required_items[$i]}" "$i")
    done
}

# Answers dialog screens in stream order, given TYPE TITLE ANSWER alternatives:
#   ANSWER is the answer to send; a single triple answers its screen directly
#   -f ANSWER is a handler function called with the matched TITLE
#   -d ANSWER matches on menu item description and sends the matching key
#   -i ITEM requires a full menu item line to contain ITEM before matching
#   -n does not answer the matched screen and takes no ANSWER argument
#   -r before a TITLE or description matches it as an extended regex
#   -x before a triple answers that screen and then returns
#   -l LABEL logs entry and exit; without it nothing is logged
# Usage: dialog_answer [-l LABEL] [-x] TYPE [-r] TITLE [-i [-r] ITEM] [-n | -f ANSWER | -d [-r] ANSWER | ANSWER] ...
dialog_answer() {
    local usage="dialog_answer requires [-l LABEL] [-x] TYPE [-r] TITLE [-i [-r] ITEM] [-n | -f ANSWER | -d [-r] ANSWER | ANSWER] ..."
    local label=''
    local keys=() types=() answers=() modes=() matchers=() item_matchers=() required_item_matchers=() required_items=() answered=() terminal=()
    local pending=() count i

    if [ "${1:-}" = "-l" ]; then
        [ $# -ge 2 ] || die "$usage"
        label=$2
        shift 2
    fi
    dialog_parse_alternatives "$@"
    count=${#keys[@]}
    [ "$count" -gt 0 ] || die "$usage"

    # A lone alternative needs no dispatch, but still matches through the same
    # path so that -i is honored and -n waits for its screen before returning.
    if [ "$count" -eq 1 ]; then
        dialog_build_pending_alternatives
        dialog_wait_alternative "${pending[@]}" >/dev/null
        dialog_answer_alternative 0
        return 0
    fi

    [[ " ${terminal[*]} " = *" true "* ]] || die "$usage"

    [ -z "$label" ] || log_write "🔀" "Answering $label questions with $count alternatives"
    while :; do
        dialog_build_pending_alternatives
        dialog_wait_alternative "${pending[@]}"
        i=$?
        dialog_answer_alternative "$i"
        answered[i]=true
        if [ "${terminal[$i]}" = true ]; then
            [ -z "$label" ] || log_write "🔀" "Exiting $label questions after answering \"${keys[$i]}\""
            return 0
        fi
    done
}
