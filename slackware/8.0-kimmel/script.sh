script_import ../dialog-setup.sh

screen_wait -l "boot:"
kb_send_line ""
screen_wait -l "Enter 1 to select a keyboard map:"
kb_send_line ""

AUTOCONF_PROMPT="root@$NET_HOSTNAME:~#"
XWMCONFIG=true
dialog_setup
