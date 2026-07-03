source "$(dirname "$QEMU_INSTALL_SCRIPT")/../c-install.sh"

BOOT_SLEEP=1
COLOR_PROMPT=false
LANGUAGE_PROMPT=true
KEYBOARD_EARLY=true
PCMCIA_PROMPT=false
CDROM_TYPE_PROMPT=false
INSERT_CD_PROMPT="Insert your Red Hat CD"
POST_INSTALL_FLOW=51
TIMEZONE_PROMPT="Configure Timezones"
LILO_EXTRA_F12=1
BOOTDISK_PROMPT=true

start_install

script_wait_string "Disk Setup"
script_press_key tab # choose fdisk
script_press_key ret # choose initialize
script_wait_string "Partition Disks"
partition_disk_helper
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

select_components_default
finish_components_selection

script_wait_string "Probing found a PS/2 mouse"
script_press_key f12 # next screen
script_wait_string "Configure Mouse"
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
