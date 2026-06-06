script_boot_lilo
script_change_floppy "Please remove the boot kernel disk from your floppy drive"
script_wait_screen "VFS: Insert root floppy and press ENTER"
script_send_return
script_login "slackware login:"
script_run_autoinst "#"
script_finish_reboot
