script_import ../perl-install.sh

boot_loader
load_single_ramdisk rootdisk.img
vga_wait "Welcome to the Red Hat Commercial Linux installation program!"
kb_press ret
vga_wait "Important Copyright Notice"
kb_press ret
insert_boot_disk
