script_wait_line "boot:"
script_press_key ret
script_wait_line "VFS: Insert ramdisk floppy and press ENTER"
script_change_floppy rootdisk.img
script_press_key ret
script_wait_string "Welcome to the Red Hat Commercial Linux installation program!"
script_press_key ret
script_wait_string "Important Copyright Notice"
script_press_key ret
script_wait_string "Please insert your BOOT disk"
script_change_floppy boot.img
script_press_key ret