script_import ../pkgtool.sh

vga_wait -l "boot:"
kb_type -n ""

XWMCONFIG=true
pkgtool_setup
