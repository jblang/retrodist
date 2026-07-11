script_import ../perl-install.sh

boot_loader
load_single_ramdisk rootdisk.img
vga_wait "Welcome to the Red Hat Commercial Linux installation program!"
kb_press_key ret
vga_wait "Important Copyright Notice"
kb_press_key ret
insert_boot_disk
