script_import ../pkgtool.sh

INSTALL_MODE=VERBOSE

vga_wait -l "boot:"
kb_type -n ""
vga_wait -l "VFS: Insert ramdisk floppy and press ENTER"
script_change_floppy root.img
kb_press ret
pkgtool_setup
