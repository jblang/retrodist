script_import ../dialog-setup.sh

screen_wait -l "boot:"
kb_send_line ""
screen_wait -l "Please remove the boot kernel disk from your floppy drive, insert a"
script_change_floppy root.img
kb_press_key ret

SETUP_SOURCE=$FAT_PARTITION
dialog_setup
