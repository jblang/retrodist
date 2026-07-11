script_import ../pkgtool.sh

vga_wait -l "boot:"
kb_send_line ""
vga_wait -l "Enter 1 to select a keyboard map:"
kb_send_line ""

POSTINST_PROMPT="root@$NET_HOSTNAME:~#"
XWMCONFIG=true
pkgtool_setup
