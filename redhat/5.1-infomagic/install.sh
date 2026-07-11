script_import ../c-install.sh

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

vga_wait "Disk Setup"
kb_press_key tab # choose fdisk
kb_press_key ret # choose initialize
vga_wait "Partition Disks"
partition_disk_helper
vga_wait "Partition Disks"
kb_press_key ret
vga_wait "Current Disk Partitions"
kb_press_key down
kb_press_key ret
kb_send_line "/"
kb_press_key f12
vga_wait "Active Swap Space" # [sic]
kb_press_key f12 # selects OK
vga_wait "Partitions To Format"
kb_press_key spc # selects hda2
kb_press_key f12 # next screen

select_components_default
finish_components_selection

vga_wait "Probing found a PS/2 mouse"
kb_press_key f12 # next screen
vga_wait "Configure Mouse"
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
reboot_and_postinst
