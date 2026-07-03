source "$(dirname "$QEMU_INSTALL_SCRIPT")/../perl-install.sh"

BOOT_COMMAND="linux root=/dev/hdc"

boot_loader
script_wait_string "This script will walk you through each step of the installation."
script_press_key ret
script_wait_string "Color Screen"
script_press_key ret
script_wait_string "Text based install"
script_press_key ret

partition_disk "Disk Partitions"
script_wait_string "Do you want to use this as a swap partition?"
script_press_key y
script_wait_string "Do you want to configure ethernet TCP/IP networking"
configure_network_common netmask-first
format_root

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

configure_x11_common
confirm_network_configured
skip_modem_setup
configure_system_clock "How does your system clock store the time?"
select_timezone
select_keymap
install_lilo
skip_user_account
set_blank_root_password
reboot_to_installed_system
run_first_boot_autoconf
