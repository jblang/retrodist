script_import ../pkgtool.sh

vga_wait -l "boot:"
kb_type -n ""
vga_wait -l "VFS: Insert ramdisk floppy and press ENTER"
script_change_floppy root.img
kb_press ret

SETUP_SOURCE=/dev/hdb1
pkgtool_setup