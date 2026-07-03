script_boot
script_wait_line "VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER"
script_change_floppy root.img
script_press_key ret
script_wait_string "Select Color or Monochrome"
script_press_key alt-f2
script_wait_string "Please press Enter to activate this console."
script_press_key ret
script_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
script_wait_line "ATTN: Press ENTER to reboot."
script_set_boot c
script_press_key ret
