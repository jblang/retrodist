source "$(dirname "$QEMU_INSTALL_SCRIPT")/../tty-setup.sh"

script_boot
script_wait_line "Please remove the boot kernel disk from your floppy drive, insert a"
script_change_floppy root.img
script_press_key ret
tty_setup