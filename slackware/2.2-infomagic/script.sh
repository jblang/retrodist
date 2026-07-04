source "$(dirname "$QEMU_INSTALL_SCRIPT")/../tty-setup.sh"

script_boot
script_wait_line "VFS: Insert ramdisk floppy and press ENTER"
script_change_floppy root.img
script_press_key ret
tty_setup