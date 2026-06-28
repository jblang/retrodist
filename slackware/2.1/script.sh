script_wait_line "boot:"
script_press_key ret
script_wait_line "Please remove the boot kernel disk from your floppy drive, insert a"
script_change_floppy root.img
script_press_key ret
script_wait_line "slackware login:"
script_send_line root
script_wait_line "#"
script_send_line "$SCRIPT_AUTOINST_COMMAND"
script_wait_line "ATTN: Press ENTER to reboot." 600
script_set_boot c
script_press_key ret
