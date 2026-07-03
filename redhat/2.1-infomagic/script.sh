source "$(dirname "$QEMU_INSTALL_SCRIPT")/../perl-install.sh"

boot_loader
load_two_ramdisks
script_wait_string "Welcome to the Red Hat Linux installation program!"
script_press_key ret
insert_boot_disk
script_wait_string "Red Hat supports a number of different sources for installation."
script_press_key ret
script_wait_string "Text based install"
script_press_key t # selects text-based install
script_press_key ret

partition_disk "Do you need to partition your disks?"
script_wait_string "Do you want to use this as a swap partition?"
script_press_key y
script_press_key ret # handle swap formatting error
script_press_key ret
script_press_key ret

script_wait_string "Do you want to configure networking"
configure_network_common network-first

script_wait_string "I think I've found the Red Hat CD-ROM"
script_press_key y

format_root

script_wait_string "Select each series that you want to install."
# Manual selection:
# 	[ ] Shells
# 	[ ] Emacs
# 	[ ] DOS Compatibility
script_press_key down 3
# 	[ ] Printing
script_press_key spc
# 	[X] Printing
# 	[ ] Networking
# 	[ ] Network Admin
# 	[ ] Networking Servers
# 	[ ] Development Libraries
# 	[ ] Fortran
script_press_key down 6
# 	[ ] X Windows
script_press_key spc
# 	[X] X Windows
script_press_key down
# 	[ ] X Games
script_press_key spc
# 	[X] X Games
script_press_key down
# 	[ ] X Applications
script_press_key spc
# 	[X] X Applications
script_press_key down
# 	[ ] Development
script_press_key spc
# 	[X] Development
script_press_key down
# 	[ ] X Development
script_press_key spc
# 	[X] X Development
# 	[ ] TeX
# 	[ ] Communications
script_press_key down 3
# 	[ ] Applications
script_press_key spc
# 	[X] Applications
# 	[ ] Mail
# 	[ ] Tcl-Tk Extensions
script_press_key down 3
# 	[ ] Games
script_press_key spc
# 	[X] Games
script_press_key down
# 	[ ] Documentation
script_press_key spc
# 	[X] Documentation
# 	[ ] News
# 	[ ] a.out compatitibility
# 	[ ] Other
script_press_key ret

# completes package selection
script_wait_string "Which type of video card you you have?" # [sic]
script_press_key s # selects SVGA
script_press_key ret

# packages install here

# post installation configuration
configure_x11_common
confirm_network_configured
skip_modem_setup
configure_system_clock "Is your system clock set to local time"
select_timezone
select_keymap
install_lilo
skip_user_account
set_blank_root_password true
reboot_to_installed_system
run_first_boot_autoconf
