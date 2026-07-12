script_import ../perl-install.sh

boot_loader
load_two_ramdisks
vga_wait "Welcome to the Red Hat Linux installation program!"
kb_press ret
insert_boot_disk
vga_wait "Red Hat supports a number of different sources for installation."
kb_press ret
vga_wait "Text based install"
kb_press t # selects text-based install
kb_press ret

partition_disk "Do you need to partition your disks?"
vga_wait "Do you want to use this as a swap partition?"
kb_press y
kb_press ret # handle swap formatting error
kb_press ret
kb_press ret

vga_wait "Do you want to configure networking"
configure_network_common network-first

vga_wait "I think I've found the Red Hat CD-ROM"
kb_press y

format_root

vga_wait "Select each series that you want to install."
# Manual selection:
# 	[ ] Shells
# 	[ ] Emacs
# 	[ ] DOS Compatibility
kb_repeat down 3
# 	[ ] Printing
kb_press spc
# 	[X] Printing
# 	[ ] Networking
# 	[ ] Network Admin
# 	[ ] Networking Servers
# 	[ ] Development Libraries
# 	[ ] Fortran
kb_repeat down 6
# 	[ ] X Windows
kb_press spc
# 	[X] X Windows
kb_press down
# 	[ ] X Games
kb_press spc
# 	[X] X Games
kb_press down
# 	[ ] X Applications
kb_press spc
# 	[X] X Applications
kb_press down
# 	[ ] Development
kb_press spc
# 	[X] Development
kb_press down
# 	[ ] X Development
kb_press spc
# 	[X] X Development
# 	[ ] TeX
# 	[ ] Communications
kb_repeat down 3
# 	[ ] Applications
kb_press spc
# 	[X] Applications
# 	[ ] Mail
# 	[ ] Tcl-Tk Extensions
kb_repeat down 3
# 	[ ] Games
kb_press spc
# 	[X] Games
kb_press down
# 	[ ] Documentation
kb_press spc
# 	[X] Documentation
# 	[ ] News
# 	[ ] a.out compatitibility
# 	[ ] Other
kb_press ret

# completes package selection
vga_wait "Which type of video card you you have?" # [sic]
kb_press s # selects SVGA
kb_press ret

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
redhat_run_postinst
