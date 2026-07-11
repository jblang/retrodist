script_import ../pkgtool.sh

vga_wait -l "boot:"
kb_send_line ""

POSTINST_PROMPT="root@$NET_HOSTNAME:~#"
XWMCONFIG=true
pkgtool_setup
