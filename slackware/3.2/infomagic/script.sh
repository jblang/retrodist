script_boot_lilo
script_change_floppy "VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER"
script_login "slackware login:"
script_run_autoinst "#"
script_finish_reboot
