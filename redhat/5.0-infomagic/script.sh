script_import ../c-install.sh

KEYBOARD_EARLY=true
PCMCIA_PROMPT=false
CDROM_TYPE_PROMPT=false
INSERT_CD_PROMPT="Insert your Red Hat CD"
POST_INSTALL_FLOW=50
TIMEZONE_PROMPT="Configure Timezones"
LILO_EXTRA_F12=1

start_install

screen_wait "Which tool would you like to use?"
kb_press_key tab # fdisk
kb_press_key ret
screen_wait "Partition Disks"
partition_disk_helper
screen_wait "Partition Disks"
kb_press_key ret # done
screen_wait "Select Root Partition"
kb_press_key ret # /dev/hda2
screen_wait "Partition Disk"
kb_press_key f12 # done
screen_wait "Active Swap Space" # [sic]
kb_press_key f12 # ok
screen_wait "Format Partitions"
kb_press_key spc # hda2
kb_press_key f12 # next screen

select_components_default
finish_components_selection

screen_wait "Probing found a PS/2 mouse"
kb_press_key f12 # next screen
screen_wait "Emulate Three Buttons"
kb_press_key f12 # next screen
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
