script_wait_line "boot:"
script_press_key ret
sleep 1 # wait for lilo "Welcome to Red Hat Linux" to scroll off
script_wait_string "Welcome to Red Hat Linux!"
script_press_key f12
script_wait_string "Choose a Language"
script_press_key f12
script_wait_string "Keyboard Type"
script_press_key f12
script_wait_string "Installation Method"
script_press_key f12 # selects CDROM
script_wait_string "Insert your Red Hat CD"
script_press_key f12
script_wait_string "Installation Path"
script_press_key f12 # selects Install
script_wait_string "Do you have any SCSI adapters?"
script_press_key f12 # selects no
script_wait_string "Disk Setup"
script_press_key tab # choose fdisk
script_press_key ret # choose initialize
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
script_press_key ret
script_wait_string "Current Disk Partitions"
script_press_key down
script_press_key ret
script_send_line "/"
script_press_key f12
script_wait_string "Active Swap Space" # [sic]
script_press_key f12 # selects OK
script_wait_string "Partitions To Format"
script_press_key spc # selects hda2
script_press_key f12 # next screen
script_wait_string "Components to Install"
# Default selection:
# 	[ ] Printer Support
# 	[*] X Window System                                        
# 	[*] Mail/WWW/News Tools                                    
# 	[ ] DOS/Windows Connectivity                               
# 	[*] File Managers                                          
# 	[ ] Graphics Manipulation                                  
# 	[ ] X Games                                                
# 	[ ] Console Games                                          
# 	[*] X multimedia support
# 	[*] Console Multimedia                                     
# 	[ ] Print Server                                           
# 	[*] Networked Workstation                                  
# 	[*] Dialup Workstation                                     
# 	[ ] News Server                                            
# 	[ ] NFS Server                                             
# 	[ ] SMB (Samba) Connectivity                               
# 	[ ] IPX/Netware(tm) Connectivity                           
# 	[ ] Anonymous FTP/Gopher Server
# 	[ ] Web Server                                             
# 	[ ] DNS Name Server                                        
# 	[ ] Postgres (SQL) Server                                  
# 	[ ] Network Management Workstation                         
# 	[ ] TeX Document Formatting                                
# 	[ ] Emacs                                                  
# 	[ ] Emacs with X windows                                   
# 	[ ] C Development                                          
# 	[ ] Development Libraries
# 	[ ] C++ Development                                        
# 	[ ] X Development                                          
# 	[ ] Extra Documentation
# 	[ ] Everything
script_press_key f12 # next screen
script_wait_string "Install log"
script_press_key f12
script_wait_string "Probing found a PS/2 mouse" 600
script_press_key f12 # next screen
script_wait_string "Configure Mouse" 600
script_press_key f12 # next screen
script_wait_string "X Server : SVGA" 
script_press_key f12 # next screen
script_wait_string "Monitor Setup"
script_press_key down # highlight first non-custom
script_press_key f12 # select it
script_wait_string "Screen Configuration"
script_press_key f12 # select Don't Probe
script_wait_string "Video Memory"
script_press_key down 4 # scroll down to 4096
script_press_key f12
script_wait_string "Clockchip Configuration"
script_press_key f12 # select Don't Probe
script_wait_string "Select Video Modes"
script_press_key f12 # next screen
script_wait_string "Network Configuration"
script_press_key f12 # next screen
script_wait_string "Digital 21040 (Tulip)"
script_press_key f12 # next screen
script_wait_string "Boot Protocol"
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
script_wait_string "Configure Timezones"
script_press_key f12 # next screen
script_wait_string "Services"
script_press_key f12 # next screen
script_wait_string "Configure Printer"
script_press_key tab # select No
script_press_key ret # press No
script_wait_string "Root Password"
script_send_line "password"
script_send_line "password"
script_press_key f12
script_wait_string "Bootdisk"
script_press_key tab # select No
script_press_key ret # press No
script_wait_string "Lilo Installation"
script_press_key f12 # select Master Boot Record
script_press_key f12 # no special options
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
