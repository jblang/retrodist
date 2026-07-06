#!/bin/sh
# Plain-text dialog adapter for installer scripting.

DIALOG_TITLE=
DIALOG_BACKTITLE=
DIALOG_OUTPUT_FD=2
DIALOG_SEPARATE_OUTPUT=0
DIALOG_PROMPT_FD=1
DIALOG_SAVED_LINES=
DIALOG_DIVIDER=--------------------------------------------------------------------------------

dialog_usage() {
    echo "fake dialog: converts dialog widgets to plain text prompts" >&2
    exit 1
}

dialog_prompt_line() {
    if [ "$DIALOG_PROMPT_FD" = 2 ]; then
        echo "$1: $2" >&2
    else
        echo "$1: $2"
    fi
}

dialog_prompt_raw() {
    if [ "$DIALOG_PROMPT_FD" = 2 ]; then
        echo "$1" >&2
    else
        echo "$1"
    fi
}

dialog_prompt_text() {
    while read dialog_line; do
        dialog_prompt_line "$1" "$dialog_line"
    done
}

dialog_prompt_item() {
    dialog_prompt_line ITEM "$1"
}

dialog_prompt_response() {
    if [ "$DIALOG_PROMPT_FD" = 2 ]; then
        echo -n "RESPONSE: " >&2
    else
        echo -n "RESPONSE: "
    fi
}

dialog_save_line() {
    if [ -n "$DIALOG_SAVED_LINES" ]; then
        DIALOG_SAVED_LINES="$DIALOG_SAVED_LINES
$1: $2"
    else
        DIALOG_SAVED_LINES="$1: $2"
    fi
}

dialog_print_saved_lines() {
    if [ -n "$DIALOG_SAVED_LINES" ]; then
        if [ "$DIALOG_PROMPT_FD" = 2 ]; then
            echo "$DIALOG_SAVED_LINES" >&2
        else
            echo "$DIALOG_SAVED_LINES"
        fi
    fi
}

dialog_read_response() {
    dialog_prompt_response
    read DIALOG_RESPONSE
}

dialog_write_response() {
    case "$DIALOG_OUTPUT_FD" in
        1) echo "$1" ;;
        2) echo "$1" >&2 ;;
        *) eval 'echo "$1" >&'"$DIALOG_OUTPUT_FD" ;;
    esac
}

dialog_write_words() {
    if [ "$DIALOG_SEPARATE_OUTPUT" = 1 ]; then
        for dialog_word in $1; do
            dialog_write_response "$dialog_word"
        done
    else
        dialog_write_response "$1"
    fi
}

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

dialog_read_status() {
    dialog_read_response
    dialog_control_exit "$DIALOG_RESPONSE"
}

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
        --msgbox | --infobox | --yesno | --inputbox | --passwordbox | --menu | --checklist | --radiolist | --textbox)
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

dialog_print_saved_lines

case "$dialog_widget" in
    --msgbox)
        dialog_text=$1
        dialog_height=$2
        dialog_width=$3
        dialog_print_header msgbox
        echo "$dialog_text" | dialog_prompt_text TEXT
        dialog_prompt_line SIZE "$dialog_height $dialog_width"
        dialog_read_status
        exit 0
        ;;
    --infobox)
        dialog_text=$1
        dialog_height=$2
        dialog_width=$3
        dialog_print_header infobox
        echo "$dialog_text" | dialog_prompt_text TEXT
        dialog_prompt_line SIZE "$dialog_height $dialog_width"
        exit 0
        ;;
    --textbox)
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
        ;;
    --yesno)
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
        ;;
    --inputbox | --passwordbox)
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
        ;;
    --menu)
        dialog_text=$1
        dialog_height=$2
        dialog_width=$3
        dialog_menu_height=$4
        shift 4
        dialog_print_header menu
        echo "$dialog_text" | dialog_prompt_text TEXT
        dialog_prompt_line SIZE "$dialog_height $dialog_width"
        dialog_prompt_line MENUHEIGHT "$dialog_menu_height"
        while [ $# -gt 1 ]; do
            dialog_prompt_item "$1 :: $2"
            shift 2
        done
        dialog_read_response
        dialog_control_exit "$DIALOG_RESPONSE"
        dialog_write_response "$DIALOG_RESPONSE"
        exit 0
        ;;
    --checklist | --radiolist)
        dialog_text=$1
        dialog_height=$2
        dialog_width=$3
        dialog_list_height=$4
        shift 4
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
        while [ $# -gt 2 ]; do
            dialog_prompt_item "$1 :: $2 $3"
            shift 3
        done
        dialog_read_response
        dialog_control_exit "$DIALOG_RESPONSE"
        if [ "$dialog_widget" = "--checklist" ]; then
            dialog_write_words "$DIALOG_RESPONSE"
        else
            dialog_write_response "$DIALOG_RESPONSE"
        fi
        exit 0
        ;;
    *)
        dialog_usage
        ;;
esac
