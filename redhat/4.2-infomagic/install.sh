script_import ../c-install.sh

KEYBOARD_EARLY=true
CDROM_TYPE_PROMPT=false
POST_INSTALL_FLOW=42
MONITOR_SELECT_KEY=f12
TIMEZONE_PROMPT="Configure Timezones"
LILO_EXTRA_F12=1

start_install
partition_4x

vga_wait "Components to Install"
# Manual selection:
# [ ] C Development
kb_press_key spc
# [X] C Development
# [ ] Development Libraries
kb_press_key down 2
# [ ] C++ Development
kb_press_key spc
# [X] C++ Development
kb_press_key down
# [ ] Printer Support
kb_press_key spc
# [X] Printer Support
kb_press_key down
# [ ] Print Server
kb_press_key spc
# [X] Print Server
# [ ] News Server
# [ ] NFS Server
# [ ] Networked Workstation
# [ ] LAN Manager Connectivity
# [ ] Anonymous FTP/Gopher Server
# [ ] Web Server
# [ ] Network Management Workstation
# [ ] Dialup Workstation
kb_press_key down 9
# [ ] Game Machine
kb_press_key spc
# [X] Game Machine
kb_press_key down
# [ ] Multimedia Machine
kb_press_key spc
# [X] Multimedia Machine
kb_press_key down
# [ ] X Window System
kb_press_key spc
# [X] X Window System
kb_press_key down
# [ ] X Development
kb_press_key spc
# [X] X Development
kb_press_key down
# [ ] X multimedia support
kb_press_key spc
# [X] X multimedia support
# [ ] Java Development
# [ ] TeX Document Formatting
# [ ] Emacs
# [ ] Emacs with X windows
# [ ] DOS/Windows Connectivity
# [ ] LAN Manager Connectivity
kb_press_key down 7
# [ ] Extra Documentation
kb_press_key spc
# [X] Extra Documentation
# [ ] Everything
kb_press_key f12 # next screen

finish_components_selection
configure_x11_4x
configure_network
configure_timezone
configure_late_keyboard
configure_services
skip_printer_setup
set_root_password
skip_bootdisk
install_lilo
reboot_and_postinst
