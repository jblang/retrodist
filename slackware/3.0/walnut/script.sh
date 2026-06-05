script_boot_lilo
script_change_floppy "VFS: Insert ramdisk floppy and press ENTER"
script_login "slackware login:"
script_run_autoinst "#"
script_finish_reboot
