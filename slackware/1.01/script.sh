LOGIN_PROMPT="darkstar login:"
script_login
SHELL_PROMPT="darkstar:/#"
script_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
script_wait_line "ATTN: Press ENTER to reboot."
script_set_boot c
script_press_key ret
