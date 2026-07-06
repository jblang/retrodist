script_import ../dialog-setup.sh

script_prompt "boot:" ""
script_wait_line "Please remove the boot kernel disk from your floppy drive, insert a"
script_change_floppy root.img
script_press_key ret
script_wait_string "VFS: Insert root floppy and press ENTER"
script_press_key ret

SETUP_SOURCE=$FAT_PARTITION
dialog_setup
