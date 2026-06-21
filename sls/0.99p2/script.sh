script_wait_string "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
script_press_key spc
script_wait_line "Enter Drive You Will Be Doing The Installation From (1/2/3/4):"
script_change_floppy root.img
script_send_line "1"
script_wait_line "#"
script_send_line "$SCRIPT_AUTOINST_COMMAND"
script_wait_string "Reattach boot.img and press Ctrl-Alt-Del in the VM to reboot."
script_change_floppy boot.img
script_press_key ctrl-alt-delete
script_wait_string "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
script_press_key spc
script_wait_line "Enter Drive You Will Be Doing The Installation From (1/2/3/4):"
script_change_floppy root.img
script_send_line "1"
script_wait_line "#"
script_send_line "$SCRIPT_AUTOINST_COMMAND"
script_wait_line "ATTN: Reattach boot.img and press ENTER."
script_change_floppy boot.img
script_press_key ret
script_wait_line "ATTN: Press ENTER to reboot." 600
script_set_boot a
script_press_key ret
script_press_key ctrl-alt-delete