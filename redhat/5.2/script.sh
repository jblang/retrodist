script_wait_line "boot:"
script_send_line "linux ks=floppy"
script_wait_string "Congratulations, installation is complete." 600
script_set_boot c
script_press_key ret
script_run_autoconf password
