script_wait_line "boot:"
script_press_key ret
script_wait_string "Enter 1 to select a keyboard map:"
script_press_key ret
script_wait_line "slackware login:"
script_send_line root
script_wait_line "#"
script_send_line "$SCRIPT_AUTOINST_COMMAND"
script_wait_line "ATTN: Press ENTER to reboot." 600
script_set_boot c
script_press_key ret
