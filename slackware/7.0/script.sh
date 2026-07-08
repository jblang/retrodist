script_import ../pkgtool.sh

screen_wait -l "boot:"
kb_send_line ""

XWMCONFIG=true
pkgtool_setup
