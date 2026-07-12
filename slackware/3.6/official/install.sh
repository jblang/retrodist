script_import ../../pkgtool.sh

vga_wait -l "boot:"
kb_type -n ""
vga_wait -l "VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER"
script_change_floppy root.img
kb_press ret

SETUP_SOURCE=$FAT_PARTITION
pkgtool_setup
