screen_wait -l "darkstar login:"
kb_send_line "root"
SHELL_PROMPT="darkstar:/#"
serial_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
serial_wait -l "ATTN: Press ENTER to reboot."
script_set_boot c
serial_send ""
