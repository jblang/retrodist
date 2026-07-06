script_import ../c-install.sh

KEYBOARD_EARLY=true
CDROM_TYPE_PROMPT=false
POST_INSTALL_FLOW=42
MONITOR_SELECT_KEY=f12
TIMEZONE_PROMPT="Configure Timezones"
LILO_EXTRA_F12=1

start_install
partition_4x

script_wait_string "Components to Install"
# Manual selection:
# [ ] C Development
script_press_key spc
# [X] C Development
# [ ] Development Libraries
script_press_key down 2
# [ ] C++ Development
script_press_key spc
# [X] C++ Development
script_press_key down
# [ ] Printer Support
script_press_key spc
# [X] Printer Support
script_press_key down
# [ ] Print Server
script_press_key spc
# [X] Print Server
# [ ] News Server
# [ ] NFS Server
# [ ] Networked Workstation
# [ ] LAN Manager Connectivity
# [ ] Anonymous FTP/Gopher Server
# [ ] Web Server
# [ ] Network Management Workstation
# [ ] Dialup Workstation
script_press_key down 9
# [ ] Game Machine
script_press_key spc
# [X] Game Machine
script_press_key down
# [ ] Multimedia Machine
script_press_key spc
# [X] Multimedia Machine
script_press_key down
# [ ] X Window System
script_press_key spc
# [X] X Window System
script_press_key down
# [ ] X Development
script_press_key spc
# [X] X Development
script_press_key down
# [ ] X multimedia support
script_press_key spc
# [X] X multimedia support
# [ ] Java Development
# [ ] TeX Document Formatting
# [ ] Emacs
# [ ] Emacs with X windows
# [ ] DOS/Windows Connectivity
# [ ] LAN Manager Connectivity
script_press_key down 7
# [ ] Extra Documentation
script_press_key spc
# [X] Extra Documentation
# [ ] Everything
script_press_key f12 # next screen

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
reboot_and_autoconf
