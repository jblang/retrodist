source "$(dirname "$QEMU_INSTALL_SCRIPT")/../perl-install.sh"

boot_loader
load_single_ramdisk rootdisk.img
script_wait_string "Welcome to the Red Hat Commercial Linux installation program!"
script_press_key ret
script_wait_string "Important Copyright Notice"
script_press_key ret
insert_boot_disk
