script_wait_screen "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
script_press_key spc
script_change_floppy "Enter Drive You Will Be Doing The Installation From" root.img "1"
script_run_autoinst "#"
script_wait_screen "Reattach boot.img and press Ctrl-Alt-Del in the VM to reboot."
qmp_change_image boot.img
sleep 1
script_press_key ctrl-alt-delete
script_wait_screen "Press <RETURN> to see SVGA-modes available or <SPACE> to continue"
script_press_key spc
script_change_floppy "Enter Drive You Will Be Doing The Installation From" root.img "1"
script_run_autoinst "#"
script_answer_prompt "groff.1.Z already exists" "y"
script_answer_prompt "groff_mmse.7.Z already exists" "y"
script_change_floppy "Reattach boot.img and press ENTER." boot.img
script_finish_reboot a
