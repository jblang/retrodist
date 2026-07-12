vga_wait -l "boot:"
kb_type -n "text"
vga_wait "Congratulations, installation is complete."
script_set_boot c
kb_press ret
