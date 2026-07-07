screen_wait -l "boot:"
kb_send_line ""
screen_wait "Enter 1 to select a keyboard map:"
kb_press_key ret
screen_wait -l "slackware login:"
kb_send_line "root"
serial_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
serial_wait -l "ATTN: Press ENTER to reboot."
script_set_boot c
serial_send ""
