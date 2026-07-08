# shellcheck shell=sh
# common scripts
. "$AUTOINST_D/logging.sh"
. "$AUTOINST_D/diskutil.sh"

# helper functions that load helper scripts
slackware_sysinstall() {
    . "$AUTOINST_D/install/sysinst.sh"
    _slackware_sysinstall "$@"
}

# Load the SLS sysinstall installer.
sls_sysinstall() {
    . "$AUTOINST_D/install/sysinst.sh"
    _sls_sysinstall "$@"
}

# Load the Debian 1.x base installer.
debian_install_base() {
    . "$AUTOINST_D/install/debian.sh"
    _debian_install_base "$@"
}

# Load the Debian 0.91 base installer.
debian_091_install_base() {
    . "$AUTOINST_D/install/deb091.sh"
    _debian_091_install_base "$@"
}

# Load the Debian 0.91 package installer.
debian_091_install_packages() {
    . "$AUTOINST_D/install/deb091.sh"
    _debian_091_install_packages "$@"
}

# Load the module autoloading configurator.
mod_config() {
    . "$AUTOINST_D/config/modules.sh"
    _mod_config "$@"
}

# Load the network configurator.
net_config() {
    . "$AUTOINST_D/config/net.sh"
    _net_config "$@"
}

# Load the serial console configurator.
tty_config() {
    . "$AUTOINST_D/config/tty.sh"
    _tty_config "$@"
}

# Load the X11 configurator.
x11_config() {
    . "$AUTOINST_D/config/x11.sh"
    _x11_config "$@"
}

# Load the mail configurator.
mail_config() {
    . "$AUTOINST_D/config/mail.sh"
    _mail_config "$@"
}
