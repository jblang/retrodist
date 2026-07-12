script_import ../pkgtool.sh

vga_wait -l "boot:"
kb_type -n ""

POSTINST_PROMPT="root@$NET_HOSTNAME:~#"
XWMCONFIG=true
pkgtool_setup
