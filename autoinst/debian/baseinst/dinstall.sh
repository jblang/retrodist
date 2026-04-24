. "$INSTMOUNT/autoinst.d/debian/baseinst/shared.sh"

extract_base_system

if [ -n "$DEBIAN_PREPARE_FUNCTION" ]; then
    echo "### Configuring base system..."
    $DEBIAN_PREPARE_FUNCTION
fi

install_boot_floppy_kernel
install_driver_modules
configure_driver_modules

echo "### Configuring base system..."
copy_base_configuration_hooks

echo "### Configuring network..."
write_network_configuration

install_lilo
