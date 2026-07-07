screen_wait -l "boot:"
kb_send_line ""
screen_wait -l "VFS: Insert ramdisk floppy and press ENTER"
script_change_floppy root.img
kb_press_key ret
screen_wait -l "slackware login:"
kb_send_line "root"
serial_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
serial_wait -l "ATTN: Press ENTER to reboot."
script_set_boot c
serial_send ""
