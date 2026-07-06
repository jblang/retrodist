script_prompt "boot:" ""
script_wait_string "Select Color or Monochrome"
script_press_key alt-f2
script_wait_string "Please press Enter to activate this console."
script_press_key ret
script_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
script_wait_line "ATTN: Press ENTER to reboot."
script_set_boot c
script_press_key ret
