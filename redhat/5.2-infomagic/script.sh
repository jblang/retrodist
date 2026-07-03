script_boot "linux ks=floppy"
script_wait_string "Congratulations, installation is complete."
script_set_boot c
script_press_key ret

LOGIN_PROMPT="localhost login:"
SHELL_PROMPT="[root@localhost /root]#"
script_run_autoconf password
