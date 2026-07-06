script_import ../c-install.sh

KEYBOARD_EARLY=true
PCMCIA_PROMPT=false
CDROM_TYPE_PROMPT=false
INSERT_CD_PROMPT="Insert your Red Hat CD"
POST_INSTALL_FLOW=50
TIMEZONE_PROMPT="Configure Timezones"
LILO_EXTRA_F12=1

start_install

script_wait_string "Which tool would you like to use?"
script_press_key tab # fdisk
script_press_key ret
script_wait_string "Partition Disks"
partition_disk_helper
script_wait_string "Partition Disks"
script_press_key ret # done
script_wait_string "Select Root Partition"
script_press_key ret # /dev/hda2
script_wait_string "Partition Disk"
script_press_key f12 # done
script_wait_string "Active Swap Space" # [sic]
script_press_key f12 # ok
script_wait_string "Format Partitions"
script_press_key spc # hda2
script_press_key f12 # next screen

select_components_default
finish_components_selection

script_wait_string "Probing found a PS/2 mouse"
script_press_key f12 # next screen
script_wait_string "Emulate Three Buttons"
script_press_key f12 # next screen
configure_x11_5x_common

configure_network
configure_timezone
configure_late_keyboard
configure_services
skip_printer_setup
set_root_password
skip_bootdisk
install_lilo
reboot_and_autoconf
