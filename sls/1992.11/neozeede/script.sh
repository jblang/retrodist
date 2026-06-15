script_wait_screen_text "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
script_press_key spc
script_change_floppy "Enter Drive You Will Be Doing The Installation From (1/2/3/4):" root.img "1"
script_run_autoinst "#"
script_wait_screen_text "Reattach boot.img and press Ctrl-Alt-Del in the VM to reboot."
qmp_change_image boot.img
sleep 1
script_press_key ctrl-alt-delete
script_wait_screen_text "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
script_press_key spc
script_change_floppy "Enter Drive You Will Be Doing The Installation From (1/2/3/4):" root.img "1"
script_run_autoinst "#"
# usr/man/cat1/groff.1.Z already exists; do you wish to overwrite usr/man/cat1/groff.1.Z (y or n)? y
script_answer_prompt "ff.1.Z (y or n)?" "y"
# usr/man/cat7/groff_mmse.7.Z already exists; do you wish to overwrite usr/man/cat7/groff_mmse.7.Z (y or n)?
script_answer_prompt "7/groff_mmse.7.Z (y or n)?" "y"
script_change_floppy "ATTN: Reattach boot.img and press ENTER." boot.img
script_finish_reboot a
