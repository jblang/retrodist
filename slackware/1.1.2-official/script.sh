source "$(dirname "$QEMU_INSTALL_SCRIPT")/../tty-setup.sh"

script_wait_line "Please remove the boot kernel disk from your floppy drive,"
script_change_floppy root.img
script_press_key ret
script_wait_string "VFS: Insert root floppy and press ENTER"
script_press_key ret

SETUP_HOSTNAME="darkstar"
tty_setup
