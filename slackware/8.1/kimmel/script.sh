script_boot_lilo
script_wait_screen_text "Enter 1 to select a keyboard map:"
script_send_return
script_login "slackware login:"
script_run_autoinst "root@slackware:/#"
script_finish_reboot
