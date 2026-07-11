#!/bin/sh
# Plain-text dialog adapter for installer scripting.
#
# Several installers (Slackware 1.1.2+, Debian 1.x, Red Hat 2.1 + 3.0.3) drive
# their UI through `dialog(1)`: https://linux.die.net/man/1/dialog
#
# This script stands in for that binary. Instead of drawing a curses UI, it
# renders each widget as labeled plain text so unattended host scripts can read
# the prompt and send an answer back. The same prompt text is echoed to the
# console for logs and, when available, to the serial control channel used by
# `hostlib/script-dialog.sh`.
#
# Keep prompt output separate from result output. Real dialog writes selected
# or typed values to stderr by default, unless options such as --stdout,
# --stderr, or --output-fd choose another fd. Slackware setup scripts commonly
# redirect that result stream into files like /tmp/SeTtagpath, so explanatory
# prompt text must never leak onto the configured result fd.
#
# Button choices are returned as dialog-compatible status codes: OK/Yes is 0,
# Cancel/No is 1, and Esc is 255. Value widgets write their selected tag or
# typed text to the result fd. Checklist output follows dialog's
# --separate-output convention when requested.
#
# This file runs in old installer environments. Keep it plain /bin/sh and avoid
# newer shell features or dependencies beyond the small POSIX toolset already
# used here.

DIALOG_TITLE=
DIALOG_BACKTITLE=
DIALOG_DEFAULT_ITEM=
DIALOG_OUTPUT_FD=2
DIALOG_SEPARATE_OUTPUT=0
DIALOG_PROMPT_FD=1
DIALOG_SAVED_LINES=
DIALOG_DIVIDER=--------------------------------------------------------------------------------
DIALOG_SERIAL_INFOBOXES=${DIALOG_SERIAL_INFOBOXES:-0}
DIALOG_SERIAL_MUTED=0

# Prints a short adapter usage message and exits like dialog would.
dialog_usage() {
    echo "fake dialog: converts dialog widgets to plain text prompts" >&2
    exit 1
}

# Match real dialog's no-item usage error before drawing anything.
dialog_require_items() {
    if [ "$1" -lt "$2" ]; then
        echo "fake dialog: $3 requires at least one item" >&2
        exit 255
    fi
}

# Emits a labeled prompt line through the shared prompt writer.
dialog_prompt_line() {
    dialog_prompt_raw "$1: $2"
}

# Sends prompts to the serial port and echoes them to the console on the
# prompt fd, keeping redirected result fds clean.
dialog_prompt_raw() {
    if [ "$DIALOG_SERIAL_ON" = 1 ] && [ "$DIALOG_SERIAL_MUTED" != 1 ]; then
        echo "$1" >&5
    fi
    if [ "$DIALOG_PROMPT_FD" = 2 ]; then
        echo "$1" >&2
    else
        echo "$1"
    fi
}

# Emits each line of widget text with the supplied prompt label.
dialog_prompt_text() {
    while read dialog_line; do
        dialog_prompt_line "$1" "$dialog_line"
    done
}

# Emits one menu, checklist, or radiolist item line.
dialog_prompt_item() {
    dialog_prompt_line ITEM "$1"
}

# Prints the response prompt without completing the line.
dialog_prompt_response() {
    if [ "$DIALOG_SERIAL_ON" = 1 ]; then
        echo -n "RESPONSE: " >&5
    fi
    if [ "$DIALOG_PROMPT_FD" = 2 ]; then
        echo -n "RESPONSE: " >&2
    else
        echo -n "RESPONSE: "
    fi
}

# Saves parsed options to show them before the widget body.
dialog_save_line() {
    if [ -n "$DIALOG_SAVED_LINES" ]; then
        DIALOG_SAVED_LINES="$DIALOG_SAVED_LINES
$1: $2"
    else
        DIALOG_SAVED_LINES="$1: $2"
    fi
}

# Prints the option lines collected while parsing dialog arguments.
dialog_print_saved_lines() {
    if [ -n "$DIALOG_SAVED_LINES" ]; then
        dialog_prompt_raw "$DIALOG_SAVED_LINES"
    fi
}

# Reads one response from serial or stdin and mirrors it to the console.
dialog_read_response() {
    dialog_prompt_response
    if [ "$DIALOG_SERIAL_ON" != 1 ]; then
        read DIALOG_RESPONSE
        return
    fi
    read DIALOG_RESPONSE <&4
    # Echo the scripted answer so the console transcript is complete. The
    # host logs what it sends, so don't echo it back over serial.
    if [ "$DIALOG_PROMPT_FD" = 2 ]; then
        echo "$DIALOG_RESPONSE" >&2
    else
        echo "$DIALOG_RESPONSE"
    fi
}

# Writes one result without a newline, like real dialog.
dialog_write_response() {
    case "$DIALOG_OUTPUT_FD" in
        1) echo -n "$1" ;;
        2) echo -n "$1" >&2 ;;
        *) eval 'echo -n "$1" >&'"$DIALOG_OUTPUT_FD" ;;
    esac
}

# Writes one tag per line for --separate-output.
dialog_write_line() {
    case "$DIALOG_OUTPUT_FD" in
        1) echo "$1" ;;
        2) echo "$1" >&2 ;;
        *) eval 'echo "$1" >&'"$DIALOG_OUTPUT_FD" ;;
    esac
}

# Writes one or more selected tags using the configured output mode.
dialog_write_words() {
    if [ "$DIALOG_SEPARATE_OUTPUT" = 1 ]; then
        # Preserve quoted multi-word tags, then print one tag per line.
        eval "set -- $1"
        for dialog_word in "$@"; do
            dialog_write_line "$dialog_word"
        done
    else
        dialog_write_response "$1"
    fi
}

# Converts typed cancel and escape responses into dialog exit statuses.
dialog_control_exit() {
    case "$1" in
        cancel | CANCEL | Cancel)
            exit 1
            ;;
        esc | ESC | Esc)
            exit 255
            ;;
    esac
}

# Prints the common divider, titles, and widget type header.
dialog_print_header() {
    dialog_prompt_raw "$DIALOG_DIVIDER"
    if [ -n "$DIALOG_BACKTITLE" ]; then
        dialog_prompt_line BACKTITLE "$DIALOG_BACKTITLE"
    fi
    if [ -n "$DIALOG_TITLE" ]; then
        dialog_prompt_line TITLE "$DIALOG_TITLE"
    fi
    dialog_prompt_line TYPE "$1"
}

# Reads a status-only widget response and handles cancel or escape.
dialog_read_status() {
    dialog_read_response
    dialog_control_exit "$DIALOG_RESPONSE"
}

# Shows a message box and waits for a status-only response.
dialog_show_msgbox() {
    dialog_text=$1
    dialog_height=$2
    dialog_width=$3
    dialog_print_header msgbox
    echo "$dialog_text" | dialog_prompt_text TEXT
    dialog_prompt_line SIZE "$dialog_height $dialog_width"
    dialog_read_status
    exit 0
}

# Shows an informational message box without reading a response.
dialog_show_infobox() {
    dialog_text=$1
    dialog_height=$2
    dialog_width=$3
    dialog_print_header infobox
    echo "$dialog_text" | dialog_prompt_text TEXT
    dialog_prompt_line SIZE "$dialog_height $dialog_width"
    exit 0
}

# Shows a text file, including its contents when the path exists.
dialog_show_textbox() {
    dialog_file=$1
    dialog_height=$2
    dialog_width=$3
    dialog_print_header textbox
    dialog_prompt_line FILE "$dialog_file"
    dialog_prompt_line SIZE "$dialog_height $dialog_width"
    if [ -f "$dialog_file" ]; then
        dialog_prompt_text TEXT < "$dialog_file"
    fi
    dialog_read_status
    exit 0
}

# Shows a yes/no prompt and maps the answer to dialog status codes.
dialog_show_yesno() {
    dialog_text=$1
    dialog_height=$2
    dialog_width=$3
    dialog_print_header yesno
    echo "$dialog_text" | dialog_prompt_text TEXT
    dialog_prompt_line SIZE "$dialog_height $dialog_width"
    dialog_read_response
    case "$DIALOG_RESPONSE" in
        y | Y | yes | YES | Yes | ok | OK | true | TRUE | 1)
            exit 0
            ;;
        esc | ESC | Esc)
            exit 255
            ;;
        *)
            exit 1
            ;;
    esac
}

# Shows an input or password box and writes the entered response.
dialog_show_inputbox() {
    dialog_text=$1
    dialog_height=$2
    dialog_width=$3
    dialog_initial=$4
    case "$dialog_widget" in
        --inputbox)
            dialog_print_header inputbox
            ;;
        --passwordbox)
            dialog_print_header passwordbox
            ;;
    esac
    echo "$dialog_text" | dialog_prompt_text TEXT
    dialog_prompt_line SIZE "$dialog_height $dialog_width"
    dialog_prompt_line DEFAULT "$dialog_initial"
    dialog_read_response
    dialog_control_exit "$DIALOG_RESPONSE"
    dialog_write_response "$DIALOG_RESPONSE"
    exit 0
}

# Shows a menu or inputmenu and writes the selected item tag.
dialog_show_menu() {
    dialog_text=$1
    dialog_height=$2
    dialog_width=$3
    dialog_menu_height=$4
    shift 4
    dialog_require_items $# 2 "$dialog_widget"
    case "$dialog_widget" in
        --menu)
            dialog_print_header menu
            ;;
        --inputmenu)
            dialog_print_header inputmenu
            ;;
    esac
    echo "$dialog_text" | dialog_prompt_text TEXT
    dialog_prompt_line SIZE "$dialog_height $dialog_width"
    dialog_prompt_line MENUHEIGHT "$dialog_menu_height"
    dialog_default_item=$DIALOG_DEFAULT_ITEM
    while [ $# -gt 1 ]; do
        if [ -z "$dialog_default_item" ]; then
            dialog_default_item=$1
        fi
        dialog_prompt_item "$1 :: $2"
        shift 2
    done
    dialog_read_response
    dialog_control_exit "$DIALOG_RESPONSE"
    # An empty response selects the highlighted item, like real dialog.
    if [ -z "$DIALOG_RESPONSE" ]; then
        DIALOG_RESPONSE=$dialog_default_item
    fi
    dialog_write_response "$DIALOG_RESPONSE"
    exit 0
}

# Shows a checklist or radiolist and writes the selected tag or tags.
dialog_show_checklist() {
    dialog_text=$1
    dialog_height=$2
    dialog_width=$3
    dialog_list_height=$4
    shift 4
    dialog_require_items $# 3 "$dialog_widget"
    case "$dialog_widget" in
        --checklist)
            dialog_print_header checklist
            ;;
        --radiolist)
            dialog_print_header radiolist
            ;;
    esac
    echo "$dialog_text" | dialog_prompt_text TEXT
    dialog_prompt_line SIZE "$dialog_height $dialog_width"
    dialog_prompt_line LISTHEIGHT "$dialog_list_height"
    dialog_defaults=
    dialog_default_item=
    while [ $# -gt 2 ]; do
        dialog_prompt_item "$1 :: $2 $3"
        case "$3" in
            [Oo][Nn] | 1)
                if [ -n "$dialog_defaults" ]; then
                    dialog_defaults="$dialog_defaults \"$1\""
                else
                    dialog_defaults="\"$1\""
                fi
                dialog_default_item=$1
                ;;
        esac
        shift 3
    done
    dialog_read_response
    dialog_control_exit "$DIALOG_RESPONSE"
    if [ "$dialog_widget" = "--checklist" ]; then
        # An empty response keeps the preselected items, like real dialog.
        if [ -z "$DIALOG_RESPONSE" ]; then
            DIALOG_RESPONSE=$dialog_defaults
        fi
        dialog_write_words "$DIALOG_RESPONSE"
    else
        if [ -z "$DIALOG_RESPONSE" ]; then
            DIALOG_RESPONSE=$dialog_default_item
        fi
        dialog_write_response "$DIALOG_RESPONSE"
    fi
    exit 0
}

# Shows a gauge and echoes changed progress messages until stdin closes.
dialog_show_gauge() {
    dialog_text=$1
    dialog_height=$2
    dialog_width=$3
    dialog_percent=${4:-0}
    dialog_print_header gauge
    echo "$dialog_text" | dialog_prompt_text TEXT
    dialog_prompt_line SIZE "$dialog_height $dialog_width"
    dialog_prompt_line PERCENT "$dialog_percent"
    # Consume updates until the writer closes the pipe: bare percent
    # lines and XXX markers are dropped, message lines are echoed when
    # they change so progress stays visible.
    dialog_gauge_last=
    while read dialog_line; do
        case "$dialog_line" in
            XXX | [0-9]*) ;;
            *)
                if [ "$dialog_line" != "$dialog_gauge_last" ]; then
                    dialog_prompt_line GAUGE "$dialog_line"
                    dialog_gauge_last=$dialog_line
                fi
                ;;
        esac
    done
    exit 0
}

# Keep the tty open on fds 4/5; otherwise it can discard buffered input.
DIALOG_SERIAL=${DIALOG_SERIAL:-/dev/ttyS3}
DIALOG_SERIAL_ON=0
if [ -w "$DIALOG_SERIAL" ]; then
    # shellcheck disable=SC2094 # Duplex device: reads and writes are distinct streams.
    exec 4<"$DIALOG_SERIAL" 5>"$DIALOG_SERIAL"
    DIALOG_SERIAL_ON=1
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --title)
            DIALOG_TITLE=$2
            shift 2
            ;;
        --backtitle)
            DIALOG_BACKTITLE=$2
            shift 2
            ;;
        --stdout)
            DIALOG_OUTPUT_FD=1
            shift
            ;;
        --stderr)
            DIALOG_OUTPUT_FD=2
            shift
            ;;
        --output-fd)
            DIALOG_OUTPUT_FD=$2
            shift 2
            ;;
        --separate-output)
            DIALOG_SEPARATE_OUTPUT=1
            shift
            ;;
        --default-item)
            dialog_save_line DEFAULT_ITEM "$2"
            DIALOG_DEFAULT_ITEM=$2
            shift 2
            ;;
        --defaultno)
            dialog_save_line DEFAULTNO yes
            shift
            ;;
        --clear | --colors | --no-collapse | --cr-wrap | --no-shadow | --ascii-lines)
            dialog_save_line OPTION "$1"
            shift
            ;;
        --ok-label | --cancel-label | --yes-label | --no-label | --extra-label | --help-label | --input-fd | --max-input | --sleep | --timeout)
            dialog_save_line OPTION "$1 $2"
            shift 2
            ;;
        --begin)
            dialog_save_line BEGIN "$2 $3"
            shift 3
            ;;
        --help)
            dialog_usage
            ;;
        --version)
            echo "fake-dialog"
            exit 0
            ;;
        --msgbox | --infobox | --yesno | --inputbox | --passwordbox | --menu | --inputmenu | --checklist | --radiolist | --textbox | --gauge)
            dialog_widget=$1
            shift
            break
            ;;
        --*)
            dialog_save_line OPTION "$1"
            shift
            ;;
        *)
            dialog_usage
            ;;
    esac
done

if [ "$DIALOG_OUTPUT_FD" = 1 ]; then
    DIALOG_PROMPT_FD=2
fi

# Infoboxes are display-only; keep them off the serial transcript by default.
if [ "$dialog_widget" = "--infobox" ] && [ "$DIALOG_SERIAL_INFOBOXES" != 1 ]; then
    DIALOG_SERIAL_MUTED=1
fi

dialog_print_saved_lines

case "$dialog_widget" in
    --msgbox)
        dialog_show_msgbox "$@"
        ;;
    --infobox)
        dialog_show_infobox "$@"
        ;;
    --textbox)
        dialog_show_textbox "$@"
        ;;
    --yesno)
        dialog_show_yesno "$@"
        ;;
    --inputbox | --passwordbox)
        dialog_show_inputbox "$@"
        ;;
    --menu | --inputmenu)
        dialog_show_menu "$@"
        ;;
    --checklist | --radiolist)
        dialog_show_checklist "$@"
        ;;
    --gauge)
        dialog_show_gauge "$@"
        ;;
    "")
        # Invoked with options but no widget (e.g. `dialog --clear`).
        exit 0
        ;;
    *)
        dialog_usage
        ;;
esac
