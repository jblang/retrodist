script_boot_lilo
script_change_floppy "Please remove the boot kernel disk from your floppy drive"
script_press_enter_on_screen "VFS: Insert root floppy and press ENTER"
script_login "slackware login:"
script_run_autoinst "#"
script_finish_reboot
