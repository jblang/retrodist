script_boot
script_wait_line "Please remove the boot kernel disk from your floppy drive, insert a"
script_change_floppy root.img
script_press_key ret
script_wait_string "VFS: Insert root floppy and press ENTER"
script_press_key ret
LOGIN_PROMPT="slackware login:"
script_login
script_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
script_wait_line "ATTN: Press ENTER to reboot."
script_set_boot c
script_press_key ret
