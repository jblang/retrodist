script_import ../pkgtool.sh

vga_wait -l "boot:"
kb_type -n ""
vga_wait -l "Please remove the boot kernel disk from your floppy drive, insert a"
script_change_floppy root.img
kb_press ret

SETUP_SOURCE=$FAT_PARTITION
pkgtool_setup
