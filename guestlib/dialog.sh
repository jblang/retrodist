#!/bin/sh
# Plain-text dialog(1) replacement for scripted installations.
# Maintain bash 1.14 and ash 0.2 compatibility; add no new external commands.
# Keep as small as possible. See README.md in this directory for more info.

rm -f /bin/dialog.bak /usr/bin/dialog.bak

TITLE=
BACKTITLE=
DEFAULT_ITEM=
OUTPUT_FD=2
SEPARATE_OUTPUT=0
PROMPT_FD=1
SAVED_LINES=
DIVIDER=--------------------------------------------------------------------------------
SERIAL_INFOBOXES=${SERIAL_INFOBOXES:-0}
SERIAL_MUTED=0

usage() {
    echo "fake dialog: converts dialog widgets to plain text prompts" >&2
    exit 1
}

require_items() {
    if [ "$1" -lt "$2" ]; then
        echo "fake dialog: $3 requires at least one item" >&2
        exit 255
    fi
}

prompt() {
    if [ "$SERIAL_ON" = 1 ] && [ "$SERIAL_MUTED" != 1 ]; then
        echo "$1" >&5
    fi
    if [ "$PROMPT_FD" = 2 ]; then
        echo "$1" >&2
    else
        echo "$1"
    fi
}

prompt_text() {
    while read line; do
        prompt "$1: $line"
    done
}

prompt_response() {
    if [ "$SERIAL_ON" = 1 ]; then
        echo -n "RESPONSE: " >&5
    fi
    if [ "$PROMPT_FD" = 2 ]; then
        echo -n "RESPONSE: " >&2
    else
        echo -n "RESPONSE: "
    fi
}

save() {
    if [ -n "$SAVED_LINES" ]; then
        SAVED_LINES="$SAVED_LINES
$1: $2"
    else
        SAVED_LINES="$1: $2"
    fi
}

read_response() {
    prompt_response
    if [ "$SERIAL_ON" != 1 ]; then
        read RESPONSE
        return
    fi
    read RESPONSE <&4
    if [ "$PROMPT_FD" = 2 ]; then
        echo "$RESPONSE" >&2
    else
        echo "$RESPONSE"
    fi
}

write_response() {
    case "$OUTPUT_FD" in
        1) echo -n "$1" ;;
        2) echo -n "$1" >&2 ;;
        *) eval 'echo -n "$1" >&'"$OUTPUT_FD" ;;
    esac
}

write_line() {
    case "$OUTPUT_FD" in
        1) echo "$1" ;;
        2) echo "$1" >&2 ;;
        *) eval 'echo "$1" >&'"$OUTPUT_FD" ;;
    esac
}

write_words() {
    if [ "$SEPARATE_OUTPUT" = 1 ]; then
        eval "set -- $1"
        for word in "$@"; do
            write_line "$word"
        done
    else
        write_response "$1"
    fi
}

control_exit() {
    case "$1" in
        cancel | CANCEL | Cancel) exit 1 ;;
        esc | ESC | Esc) exit 255 ;;
    esac
}

print_header() {
    prompt "$DIVIDER"
    if [ -n "$BACKTITLE" ]; then
        prompt "BACKTITLE: $BACKTITLE"
    fi
    if [ -n "$TITLE" ]; then
        prompt "TITLE: $TITLE"
    fi
    prompt "TYPE: $1"
}

text() {
    print_header "$1"
    echo "$2" | prompt_text TEXT
    prompt "SIZE: $3 $4"
}

read_status() {
    read_response
    control_exit "$RESPONSE"
}

msgbox() {
    text "$1" "$2" "$3" "$4"
    if [ "$1" = msgbox ]; then
        read_status
    fi
}

textbox() {
    print_header textbox
    prompt "FILE: $1"
    prompt "SIZE: $2 $3"
    if [ -f "$1" ]; then
        prompt_text TEXT < "$1"
    fi
    read_status
}

yesno() {
    text yesno "$1" "$2" "$3"
    read_response
    case "$RESPONSE" in
        y | Y | yes | YES | Yes | ok | OK | true | TRUE | 1) exit 0 ;;
        esc | ESC | Esc) exit 255 ;;
        *) exit 1 ;;
    esac
}

inputbox() {
    text "$1" "$2" "$3" "$4"
    prompt "DEFAULT: $5"
    read_response
    control_exit "$RESPONSE"
    write_response "$RESPONSE"
}

menu() {
    require_items $# 7 "$widget"
    text "$1" "$2" "$3" "$4"
    prompt "MENUHEIGHT: $5"
    shift 5
    default_item=$DEFAULT_ITEM
    while [ $# -gt 1 ]; do
        if [ -z "$default_item" ]; then
            default_item=$1
        fi
        prompt "ITEM: $1 :: $2"
        shift 2
    done
    read_response
    control_exit "$RESPONSE"
    if [ -z "$RESPONSE" ]; then
        RESPONSE=$default_item
    fi
    write_response "$RESPONSE"
}

checklist() {
    require_items $# 8 "$widget"
    text "$1" "$2" "$3" "$4"
    prompt "LISTHEIGHT: $5"
    shift 5
    defaults=
    default_item=
    while [ $# -gt 2 ]; do
        prompt "ITEM: $1 :: $2 $3"
        case "$3" in
            [Oo][Nn] | 1)
                if [ -n "$defaults" ]; then
                    defaults="$defaults \"$1\""
                else
                    defaults="\"$1\""
                fi
                default_item=$1
                ;;
        esac
        shift 3
    done
    read_response
    control_exit "$RESPONSE"
    if [ "$widget" = "--checklist" ]; then
        if [ -z "$RESPONSE" ]; then
            RESPONSE=$defaults
        fi
        write_words "$RESPONSE"
    else
        if [ -z "$RESPONSE" ]; then
            RESPONSE=$default_item
        fi
        write_response "$RESPONSE"
    fi
}

gauge() {
    text gauge "$1" "$2" "$3"
    prompt "PERCENT: ${4:-0}"
    gauge_last=
    while read line; do
        case "$line" in
            XXX | [0-9]*) ;;
            *)
                if [ "$line" != "$gauge_last" ]; then
                    prompt "GAUGE: $line"
                    gauge_last=$line
                fi
                ;;
        esac
    done
}

SERIAL=${SERIAL:-/dev/ttyS3}
SERIAL_ON=0
if [ -w "$SERIAL" ]; then
    # Duplex device: reads and writes are distinct streams.
    # shellcheck disable=SC2094
    exec 4<"$SERIAL" 5>"$SERIAL"
    SERIAL_ON=1
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --title) TITLE=$2; shift 2 ;;
        --backtitle) BACKTITLE=$2; shift 2 ;;
        --stdout) OUTPUT_FD=1; shift ;;
        --stderr) OUTPUT_FD=2; shift ;;
        --output-fd) OUTPUT_FD=$2; shift 2 ;;
        --separate-output) SEPARATE_OUTPUT=1; shift ;;
        --default-item) save DEFAULT_ITEM "$2"; DEFAULT_ITEM=$2; shift 2 ;;
        --defaultno) save DEFAULTNO yes; shift ;;
        --clear | --colors | --no-collapse | --cr-wrap | --no-shadow | --ascii-lines)
            save OPTION "$1"; shift ;;
        --ok-label | --cancel-label | --yes-label | --no-label | --extra-label | --help-label | --input-fd | --max-input | --sleep | --timeout)
            save OPTION "$1 $2"; shift 2 ;;
        --begin) save BEGIN "$2 $3"; shift 3 ;;
        --help) usage ;;
        --version) echo "fake-dialog"; exit 0 ;;
        --msgbox | --infobox | --yesno | --inputbox | --passwordbox | --menu | --inputmenu | --checklist | --radiolist | --textbox | --gauge)
            widget=$1; shift; break ;;
        --*) save OPTION "$1"; shift ;;
        *) usage ;;
    esac
done

if [ "$OUTPUT_FD" = 1 ]; then
    PROMPT_FD=2
fi

if [ "$widget" = "--infobox" ] && [ "$SERIAL_INFOBOXES" != 1 ]; then
    SERIAL_MUTED=1
fi

if [ -n "$SAVED_LINES" ]; then
    prompt "$SAVED_LINES"
fi

case "$widget" in
    --msgbox) msgbox msgbox "$@" ;;
    --infobox) msgbox infobox "$@" ;;
    --textbox) textbox "$@" ;;
    --yesno) yesno "$@" ;;
    --inputbox) inputbox inputbox "$@" ;;
    --passwordbox) inputbox passwordbox "$@" ;;
    --menu) menu menu "$@" ;;
    --inputmenu) menu inputmenu "$@" ;;
    --checklist) checklist checklist "$@" ;;
    --radiolist) checklist radiolist "$@" ;;
    --gauge) gauge "$@" ;;
    "") exit 0 ;;
    *) usage ;;
esac
