script_import ../dialog-setup.sh

script_prompt "boot:" ""
script_wait_line "VFS: Insert ramdisk floppy and press ENTER"
script_change_floppy root.img
script_press_key ret

SETUP_SOURCE=/dev/hdb1
dialog_setup