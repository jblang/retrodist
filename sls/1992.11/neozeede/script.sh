script_wait_screen "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
script_press_key spc
script_wait_screen "Enter Drive You Will Be Doing The Installation From"
qmp_change_floppy root.img
sleep 1
qmp_send_line "1"
script_wait_screen "#"
qmp_send_line "mkdir /retro && mount -t msdos /dev/hdb1 /retro && sh /retro/autoinst"
script_wait_screen "Reattach boot.img and press Ctrl-Alt-Del in the VM to reboot."
qmp_change_floppy boot.img
sleep 1
script_press_key ctrl-alt-delete

script_wait_screen "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
script_press_key spc
script_wait_screen "Enter Drive You Will Be Doing The Installation From"
qmp_change_floppy root.img
sleep 1
qmp_send_line "1"
script_wait_screen "#"
qmp_send_line "mkdir /retro && mount -t msdos /dev/hdb1 /retro && sh /retro/autoinst"
script_wait_screen "groff.1.Z already exists"
qmp_send_line "y"
script_wait_screen "groff_mmse.7.Z already exists"
qmp_send_line "y"
script_wait_screen "Reattach boot.img and press ENTER."
qmp_change_floppy boot.img
sleep 1
script_press_key ret
script_finish_reboot
