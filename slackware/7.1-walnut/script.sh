script_import ../pkgtool.sh

screen_wait -l "boot:"
kb_send_line ""

AUTOCONF_PROMPT="root@$NET_HOSTNAME:~#"
XWMCONFIG=true
pkgtool_setup
