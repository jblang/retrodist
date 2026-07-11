vga_wait -l "boot:"
kb_send_line "linux ks=floppy"
vga_wait "Congratulations, installation is complete."
script_set_boot c
kb_press_key ret

LOGIN_PROMPT="localhost login:"
SHELL_PROMPT="[root@localhost /root]#"
script_run_postinst password
