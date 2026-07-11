# shellcheck shell=bash
# Helpers for the guestlib/dialog.sh serial plain-text adapter.
#
# Guest installers such as Slackware run `dialog` for interactive screens.
# During unattended installs, the guest-side `guestlib/dialog.sh` adapter
# replaces that binary and prints each screen as labeled plain text on the
# serial transcript: TITLE, TYPE, ITEM, RESPONSE, and related metadata.
#
# This host-side interface reads that transcript through `hostlib/script-serial.sh`
# and sends answers back when the adapter prints `RESPONSE:`. Simple cases use
# `dialog_expect` for one known screen. Version-dependent flows use
# `dialog_answer`, which accepts alternatives keyed by widget type, title, and
# optional required menu items, then answers whichever matching screen appears
# next in stream order.
#
# Answers must match dialog's result contract, not the visual text on screen.
# Menu-like widgets expect the selected item tag; input widgets expect typed
# text; yes/no and msgbox-style widgets expect button words that the adapter
# converts to dialog-compatible status codes. Description matching (`-d`) is
# available when old installer versions use different tags for the same menu
# choice.

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
# matched title line (dynamic scope of dialog_wait_typed_alternative).
dialog_title_candidates() {
    local i

    candidates=()
    for ((i = 0; i < ${#titles[@]}; i++)); do
        "${matchers[$i]}" "$title_line" "TITLE: ${titles[$i]}" || continue
        candidates+=("$i")
    done
}

# Filters candidates to the alternatives the screen's TYPE line satisfies,
# dying if none do (dynamic scope of dialog_wait_typed_alternative).
dialog_probe_type() {
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
# (dynamic scope of dialog_wait_typed_alternative).
dialog_probe_required_item() {
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
dialog_wait_typed_alternative() {
    local usage="dialog_wait_typed_alternative requires [MATCHER TYPE TITLE REQUIRED_ITEM_MATCHER REQUIRED_ITEM INDEX ...]"
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

    mark=$SERIAL_LINE
    serial_wait_until "${pairs[@]}" -- >/dev/null
    title_line=$SERIAL_MATCHED_TEXT
    dialog_title_candidates
    dialog_probe_type
    dialog_probe_required_item
    serial_rewind "$mark"
    return "${indexes[$alt]}"
}

# Answers parsed alternative I (dynamic scope of dialog_answer).
dialog_answer_alt() {
    local i=$1

    if [ "${modes[$i]}" = none ]; then
        :
    elif [ "${modes[$i]}" = func ]; then
        "${answers[$i]}" "${keys[$i]}"
    elif [ "${modes[$i]}" = desc ]; then
        dialog_answer_desc "$i"
    elif [ "${matchers[$i]}" = text_contains_regex ]; then
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

# Parses the alternative triples into dialog_answer's arrays (dynamic scope).
dialog_answer_parse() {
    local key type answer mode matcher item_matcher required_item_matcher required_item terminate_next

    while [ $# -gt 0 ]; do
        terminate_next=false
        if [ "$1" = "-x" ]; then
            terminate_next=true
            shift
        fi
        [ $# -ge 3 ] || die "$usage"
        type=$1
        [ -n "$type" ] || die "$usage"
        shift
        matcher=text_contains_line
        if [ "$1" = "-r" ]; then
            matcher=text_contains_regex
            shift
        fi
        key=$1
        shift
        required_item_matcher=:
        required_item=$DIALOG_NO_REQUIRED_ITEM
        if [ "${1:-}" = "-i" ]; then
            required_item_matcher=dialog_item_matches
            shift
            if [ "${1:-}" = "-r" ]; then
                required_item_matcher=dialog_item_matches_regex
                shift
            fi
            [ $# -ge 1 ] || die "$usage"
            required_item=$1
            shift
        fi
        mode=answer
        item_matcher=''
        if [ "${1:-}" = "-n" ]; then
            mode=none
            answer=''
            shift
        elif [ "${1:-}" = "-f" ]; then
            mode=func
            shift
            [ $# -ge 1 ] || die "$usage"
            answer=$1
            shift
        elif [ "${1:-}" = "-d" ]; then
            mode=desc
            item_matcher=dialog_item_text_matches
            shift
            if [ "${1:-}" = "-r" ]; then
                item_matcher=dialog_item_text_matches_regex
                shift
            fi
            [ $# -ge 1 ] || die "$usage"
            answer=$1
            shift
        else
            [ $# -ge 1 ] || die "$usage"
            answer=$1
            shift
        fi
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
    done
}

# Rebuilds the pending quads from the unanswered alternatives (dynamic scope
# of dialog_answer).
dialog_answer_pending() {
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
    dialog_answer_parse "$@"
    count=${#keys[@]}
    [ "$count" -gt 0 ] || die "$usage"

    # A lone alternative needs no dispatch, but still matches through the same
    # path so that -i is honored and -n waits for its screen before returning.
    if [ "$count" -eq 1 ]; then
        dialog_answer_pending
        dialog_wait_typed_alternative "${pending[@]}" >/dev/null
        dialog_answer_alt 0
        return 0
    fi

    [[ " ${terminal[*]} " = *" true "* ]] || die "$usage"

    [ -z "$label" ] || log_write "🔀" "Answering $label questions with $count alternatives"
    while :; do
        dialog_answer_pending
        dialog_wait_typed_alternative "${pending[@]}"
        i=$?
        dialog_answer_alt "$i"
        answered[i]=true
        if [ "${terminal[$i]}" = true ]; then
            [ -z "$label" ] || log_write "🔀" "Exiting $label questions after answering \"${keys[$i]}\""
            return 0
        fi
    done
}
