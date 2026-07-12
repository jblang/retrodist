script_import ../pkgtool.sh

vga_wait -l "boot:"
kb_type -n ""
vga_wait -l "Enter 1 to select a keyboard map:"
kb_type -n ""

SHELL_PROMPT='root@slackware:/#'
POSTINST_PROMPT="root@$NET_HOSTNAME:~#"
XWMCONFIG=true
pkgtool_setup
