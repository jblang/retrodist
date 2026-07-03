source "$(dirname "$QEMU_INSTALL_SCRIPT")/../c-install.sh"

POST_INSTALL_FLOW=4x
X_CARD_DOWN=66
KEYBOARD_AFTER_PACKAGES=true
LILO_EXTRA_F12=1

start_install
partition_4x
select_components_40
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
