script_boot
script_wait_line "VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER"
script_change_floppy root.img
script_press_key ret
LOGIN_PROMPT="slackware login:"
script_login
script_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
script_wait_line "ATTN: Press ENTER to reboot."
script_set_boot c
script_press_key ret
