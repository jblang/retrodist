script_wait_line "boot:"
script_send_line "linux root=/dev/hdc"
script_wait_string "This script will walk you through each step of the installation."
script_press_key ret
script_wait_string "Color Screen"
script_press_key ret
script_wait_string "Text based install"
script_press_key ret
script_wait_string "Disk Partitions"
script_press_key alt-f2
script_wait_line "#"
script_send_line "mount -t msdos /dev/hdb1 /mnt && /mnt/autoinst.d/diskpart.sh /dev/hda 64"
script_wait_string "partitioned /dev/hda:"
script_send_line "umount /mnt"
script_press_key alt-f1
script_wait_string "Disk Partitions"
script_press_key n
script_wait_string "Do you want to use this as a swap partition?"
script_press_key y
script_wait_string "Do you want to configure ethernet TCP/IP networking"
script_press_key y
script_wait_string "What hostname have you selected for this computer?"
script_send_line "redhat"
script_wait_string "What domain name is this computer part of?"
script_send_line "retro.net"
script_wait_string "What is the fully qualified domain name (FQDN) of this computer?"
script_press_key ret
script_wait_string "What is the IP address of this computer?"
script_send_line "10.0.2.15"
script_wait_string "What is the netmask used by this computer?"
script_press_key ret
script_wait_string "What is the network address of this computer?"
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
script_wait_string "Use the spacebar to select all partitions to format."
script_press_key spc
script_press_key ret
script_wait_string "Are you absolutely certain that you want to format?"
script_press_key y
script_wait_string "Select each series that you want to install."
# Default selection:
# 	[X]   15.0 MB - Applications
# 	[ ]    2.0 MB - DOS Compatibility
# 	[X]   25.7 MB - Development
# 	[ ]    6.9 MB - Development Libraries
# 	[X]    6.7 MB - Documentation
# 	[ ]   13.7 MB - Emacs
# 	[X]   16.4 MB - Games
# 	[ ]    6.7 MB - Mail
# 	[X]    1.3 MB - Multimedia Programs
# 	[ ]    1.6 MB - Network Admin
# 	[ ]    2.1 MB - Networking
# 	[ ]    4.8 MB - Networking Servers
# 	[ ]    7.4 MB - Other Programming Languages
# 	[ ]    1.1 MB - Other Shells
# 	[X]    0.3 MB - Printing
# 	[ ]    2.3 MB - Serial Communications
# 	[ ]    5.8 MB - Tcl-Tk Extensions
# 	[ ]   25.1 MB - TeX
# 	[X]   17.2 MB - X Applications
# 	[X]    7.7 MB - X Development
# 	[X]   13.6 MB - X Games
# 	[X]   46.3 MB - X Windows
# 	[ ]    4.9 MB - XView
# 	[ ]    3.8 MB - a.out compatitibility
# 	[ ]   39.9 MB - Other
script_press_key ret
script_wait_string "Which X server would you like to use?"
script_press_key s # selects SVGA
script_press_key ret
script_wait_string "Would you like to select and unselect individual packages"
script_press_key n
script_wait_string "Package Installation is complete." 600
script_press_key ret
script_wait_string "Which type of mouse do you have?"
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
script_wait_string "How does your system clock store the time?"
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
script_wait_string "Reboot now?"
script_press_key y
script_wait_string "Be sure to remove the boot floppy from your floppy drive!"
script_set_boot c
script_press_key ret
