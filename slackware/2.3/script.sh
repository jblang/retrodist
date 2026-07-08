script_import ../pkgtool.sh

screen_wait -l "boot:"
kb_send_line ""
screen_wait -l "VFS: Insert ramdisk floppy and press ENTER"
script_change_floppy root.img
kb_press_key ret

pkgtool_setup
