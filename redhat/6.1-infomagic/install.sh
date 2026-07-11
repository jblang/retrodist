vga_wait -l "boot:"
kb_send_line "text"
vga_wait "Congratulations, installation is complete."
script_set_boot c
kb_press_key ret
