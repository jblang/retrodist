script_import ../dinstall.sh

screen_wait -l "boot:"
kb_send_line ""
screen_wait -l "VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER"
script_change_floppy root.img
kb_press_key ret

NET_HOSTNAME=buzz
# 1.1 has no keyboard or driver menu steps, installs the kernel from the boot
# floppy swapped back in over root.img, and logs out at the end of first boot.
KEYMAP=
DINSTALL_CONFIG_KEYBOARD=true
KERNEL_FLOPPY=boot.img
DRIVER_FLOPPY=
DINSTALL_RELOGIN=true
NET_MODULE=ne
NET_MODULE_ARGS="io=0x300 irq=9"

dinstall_setup
