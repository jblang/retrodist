screen_wait "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
kb_press_key spc
screen_wait -l "Enter Drive You Will Be Doing The Installation From (1/2/3/4):"
script_change_floppy root.img
kb_send_line "1"
serial_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
serial_wait "Reattach boot.img and press Ctrl-Alt-Del in the VM to reboot."
script_change_floppy boot.img
kb_press_key ctrl-alt-delete
screen_wait "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
kb_press_key spc
screen_wait -l "Enter Drive You Will Be Doing The Installation From (1/2/3/4):"
script_change_floppy root.img
kb_send_line "1"
serial_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
serial_wait -l "ATTN: Reattach boot.img and press ENTER."
script_change_floppy boot.img
serial_send ""
serial_wait -l "ATTN: Press ENTER to reboot."
script_set_boot a
serial_send ""
kb_press_key ctrl-alt-delete