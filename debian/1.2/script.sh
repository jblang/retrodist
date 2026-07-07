screen_wait -l "boot:"
kb_send_line ""
screen_wait "Select Color or Monochrome"
kb_press_key alt-f2
screen_wait "Please press Enter to activate this console."
kb_press_key ret
serial_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
serial_wait -l "ATTN: Press ENTER to reboot."
script_set_boot c
serial_send ""
