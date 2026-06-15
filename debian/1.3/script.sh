script_boot_lilo
script_wait_screen_text "Select Color or Monochrome"
script_press_key alt-f2
script_wait_screen_text "Please press Enter to activate this console."
script_press_key ret
script_run_autoinst "#"
script_finish_reboot
