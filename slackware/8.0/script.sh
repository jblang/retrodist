script_boot
script_wait_string "Enter 1 to select a keyboard map:"
script_press_key ret
LOGIN_PROMPT="slackware login:"
script_login
script_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
script_wait_line "ATTN: Press ENTER to reboot."
script_set_boot c
script_press_key ret
