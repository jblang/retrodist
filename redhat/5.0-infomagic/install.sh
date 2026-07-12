script_import ../c-install.sh

KEYBOARD_EARLY=true
PCMCIA_PROMPT=false
CDROM_TYPE_PROMPT=false
INSERT_CD_PROMPT="Insert your Red Hat CD"
POST_INSTALL_FLOW=50
TIMEZONE_PROMPT="Configure Timezones"
LILO_EXTRA_F12=1

start_install

vga_wait "Which tool would you like to use?"
kb_press tab # fdisk
kb_press ret
vga_wait "Partition Disks"
partition_disk_helper
vga_wait "Partition Disks"
kb_press ret # done
vga_wait "Select Root Partition"
kb_press ret # /dev/hda2
vga_wait "Partition Disk"
kb_press f12 # done
vga_wait "Active Swap Space" # [sic]
kb_press f12 # ok
vga_wait "Format Partitions"
kb_press spc # hda2
kb_press f12 # next screen

select_components_default
finish_components_selection

vga_wait "Probing found a PS/2 mouse"
kb_press f12 # next screen
vga_wait "Emulate Three Buttons"
kb_press f12 # next screen
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
