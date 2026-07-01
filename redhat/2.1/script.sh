script_wait_line "boot:"
script_press_key ret
script_wait_line "VFS: Insert ramdisk floppy and press ENTER"
script_change_floppy ramdisk1.img
script_press_key ret
script_wait_line "RHL: Insert ramdisk 2 floppy and press ENTER"
script_change_floppy ramdisk2.img
script_press_key ret
script_wait_string "Welcome to the Red Hat Linux installation program!"
script_press_key ret
script_wait_string "Please insert your BOOT disk"
script_change_floppy boot.img
script_press_key ret
script_wait_string "Red Hat supports a number of different sources for installation."
script_press_key ret
script_wait_string "Text based install"
script_press_key t # selects text-based install
script_press_key ret
script_wait_string "Do you need to partition your disks?"
script_press_key alt-f2
script_wait_line "#"
script_send_line "mount -t msdos /dev/hdb1 /mnt && /mnt/autoinst.d/diskpart.sh /dev/hda 64"
script_wait_string "partitioned /dev/hda:"
script_send_line "umount /mnt"
script_press_key alt-f1
script_wait_string "Do you need to partition your disks?"
script_press_key n
script_wait_string "Do you want to use this as a swap partition?"
script_press_key y
script_press_key ret # handle swap formatting error
script_press_key ret
script_press_key ret
script_wait_string "Do you want to configure networking"
script_press_key y
script_wait_string "What hostname have you selected for this computer?"
script_send_line "redhat"
script_wait_string "What domain name is this computer part of?"
script_send_line "retro.net"
script_wait_string "What is the fully qualified domain name (FQDN) of this computer?"
script_press_key ret
script_wait_string "What is the IP address of this computer?"
script_send_line "10.0.2.15"
script_wait_string "What is the network address of this computer?"
script_press_key ret
script_wait_string "What is the netmask used by this computer?"
script_press_key ret
script_wait_string "What is the broadcast address used by this computer?"
script_press_key ret
script_wait_string "Does this computer use a gateway?"
script_press_key y
script_wait_string "What is the IP address of the gateway used by this computer?"
script_send_line "0.2.2"
script_wait_string "Does this computer use a nameserver?"
script_press_key y
script_wait_string "What is the IP address of the nameserver?"
script_send_line "10.0.2.3"
script_wait_string "Does this computer use another nameserver?"
script_press_key n
script_wait_string "Is this correct?"
script_press_key y
script_wait_string "I think I've found the Red Hat CD-ROM"
script_press_key y
script_wait_string "Use the spacebar to select all partitions to format."
script_press_key spc
script_press_key ret
script_wait_string "Are you absolutely certain that you want to format?"
script_press_key y
script_wait_string "Select each series that you want to install."
# Manual selection:
# 	[ ] Shells
# 	[ ] Emacs
# 	[ ] DOS Compatibility
script_press_key down 3
script_press_key spc
# 	[X] Printing
# 	[ ] Networking
# 	[ ] Network Admin
# 	[ ] Networking Servers
# 	[ ] Development Libraries
# 	[ ] Fortran
script_press_key down 6
script_press_key spc
# 	[X] X Windows
script_press_key down
script_press_key spc
# 	[X] X Games
script_press_key down
script_press_key spc
# 	[X] X Applications
script_press_key down
script_press_key spc
# 	[X] Development
script_press_key down
script_press_key spc
# 	[X] X Development
# 	[ ] TeX
# 	[ ] Communications
script_press_key down 3
script_press_key spc
# 	[X] Applications
# 	[ ] Mail
# 	[ ] Tcl-Tk Extensions
script_press_key down 3
script_press_key spc
# 	[X] Games
script_press_key down
script_press_key spc
# 	[X] Documentation
# 	[ ] News
# 	[ ] a.out compatitibility
# 	[ ] Other
script_press_key ret
script_wait_string "Which type of video card you you have?" # [sic]
script_press_key s # selects SVGA
script_press_key ret
script_wait_string "Which type of mouse do you have?" 600 # wait for package installation
script_press_key p # selects ps2-bus
script_press_key ret
script_wait_string "Do you want to autoprobe?"
script_press_key n
script_wait_string "Pick a chipset."
script_press_key ret # don't care; we'll overwrite this later
script_wait_string "How much memory does your card have."
script_press_key ret
script_wait_string "Enter your clocks, separated by spaces."
script_press_key ret
script_wait_string "Please choose a monitor."
script_press_key ret
script_wait_string "Networking has already been configured"
script_press_key y
script_wait_string "No Modem"
script_press_key ret
script_wait_string "Is your system clock set to local time"
script_press_key ret
script_wait_string "Pick a time zone."
script_press_key ret
script_wait_string "Select a keymap."
script_press_key ret
script_wait_string "Do you want to install LILO?"
script_press_key y
script_wait_string "Where do you want to install LILO?"
script_press_key ret
script_wait_string "Do you need to specify hardware parameters?"
script_press_key n
script_wait_string "Do you want to indicate another operating system"
script_press_key n
script_wait_string "Do you want to create a user account?"
script_press_key n
script_wait_string "You will now enter a password for the root user"
script_press_key ret
script_press_key ret # blank password
script_wait_string "Reboot now?"
script_press_key y
script_wait_string "Be sure to remove the boot floppy from your floppy drive!"
script_set_boot c
script_press_key ret
