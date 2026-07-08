script_import ../dialog-setup.sh

screen_wait -l "boot:"
kb_send_line ""
screen_wait -l "VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER"
script_change_floppy root.img
kb_press_key ret
dialog_setup
