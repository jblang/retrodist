script_wait_line "LILO boot:"
script_press_key ret
script_wait_string "Are you using a color monitor?"
script_press_key f12 # selects yes
script_wait_string "Welcome to Red Hat Linux!"
script_press_key f12
script_wait_string "Do you need PCMCIA support?"
script_press_key f12 # selects no
script_wait_string "Installation Method"
script_press_key f12 # selects CDROM
script_wait_string "Insert your Red Hat CD into your CD drive"
script_press_key f12
script_wait_string "What type of CDROM do you have?"
script_press_key f12 # selects IDE (ATAPI)
script_wait_string "Installation Path"
script_press_key f12 # selects Install
script_wait_string "Do you have any SCSI adapters?"
script_press_key f12 # selects no
script_wait_string "Partition Disks"
script_press_key alt-f2
script_send_line "mkdir /mnt &&
	mknod /dev/hda b 3 0 &&
	mknod /dev/hdb1 b 3 65 &&
	mount -t msdos /dev/hdb1 /mnt &&
	/mnt/autoinst.d/diskpart.sh /dev/hda 64 &&
	umount /mnt"
script_wait_string "partitioned /dev/hda:"
script_press_key alt-f1
script_wait_string "Partition Disks"
script_press_key f12 # selects done
script_wait_string "Active Swap Space" # [sic]
script_press_key f12 # selects OK
script_wait_string "Select Root Partition"
script_press_key f12 # selects hda2
script_wait_string "You may now mount other partitions within your filesystem."
script_press_key down # selects /dev/hdb1
script_press_key ret # edits mount point
script_wait_string "Edit Mount Point"
script_send_line "/retro"
script_press_key f12 # next screen
script_wait_string "Format Partitions"
script_press_key spc # selects hda2
script_press_key f12 # next screen
script_wait_string "Components to Install"
# Manual selection:
script_press_key spc
# [X] C Development
# [ ] Development Libraries
script_press_key down 2
script_press_key spc
# [X] C++ Development
script_press_key down
script_press_key spc
# [X] Print Server
# [ ] News Server
# [ ] NFS Server
# [ ] Networked Workstation
# [ ] Anonymous FTP/Gopher Server
# [ ] Web Server
# [ ] Network Management Workstation
# [ ] Dialup Workstation
script_press_key down 8
script_press_key spc
# [X] Game Machine
script_press_key down
script_press_key spc
# [X] Multimedia Machine
script_press_key down
script_press_key spc
# [X] X Window System
script_press_key down
script_press_key spc
# [X] X Development
script_press_key down
script_press_key spc
# [X] X multimedia support
# [ ] TeX Document Formatting
# [ ] Emacs
# [ ] Emacs with X windows
# [ ] DOS/Windows Connectivity
script_press_key down 5
script_press_key spc
# [X] Extra Documentation
# [ ] Everything
script_press_key f12 # next screen
script_wait_string "Install log"
script_press_key f12
script_wait_string "Configure Mouse" 600
script_press_key down
script_press_key down # select PS/2
script_press_key f12 # next screen
script_wait_string "Choose A Card"
script_press_key down 24 # scroll down to Cirrus Logic
script_press_key f12 # next screen
script_wait_string "Monitor Setup"
script_press_key down # highlight first non-custom
script_press_key ret # select it
script_wait_string "Video Memory"
script_press_key down 4 # scroll down to 4096
script_press_key f12
script_wait_string "Clockchip Configuration"
script_press_key f12 # select No Clockchip Setting
script_wait_string "Select Video Modes"
script_press_key f12 # next screen
script_wait_string "Network Configuration"
script_press_key f12 # next screen
script_wait_string "Configure TCP/IP"
script_send_line "10.0.2.15"
script_press_key backspace 15 # erase default
script_send_line "255.255.255.0" # netmask
script_press_key backspace 15 # erase default
script_send_line "10.0.2.0" # network
script_press_key backspace 15 # erase default
script_send_line "10.0.2.255" # broadcast
script_press_key f12
script_wait_string "Configure Network"
script_send_line "retro.net" # domain name
script_send_line "redhat" # hostname
script_press_key backspace 15 # erase default
script_send_line "10.0.2.2" # gateway
script_press_key backspace 15 # erase default
script_send_line "10.0.2.3" # primary nameserver
script_press_key f12
script_wait_string "Configure Timezone"
script_press_key f12 # press OK
script_wait_string "Configure Keyboard"
script_press_key f12
script_wait_string "Root Password"
script_send_line "password"
script_send_line "password"
script_press_key f12
script_wait_string "Lilo Installation"
script_press_key f12 # select Master Boot Record
script_wait_string "Bootable Partitions"
script_press_key down
script_press_key ret # edit dos partition
script_press_key backspace 3
script_press_key ret # close dialog
script_press_key f12 # next screen
script_wait_string "Congratulations, installation is complete."
script_set_boot c
script_press_key ret
script_run_autoconf password
