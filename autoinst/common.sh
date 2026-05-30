# common scripts
. "$AUTOINST_D/diskutil.sh"

# helper functions that load helper scripts
slackware_sysinstall() {
    . "$AUTOINST_D/install/sysinst.sh"
    _slackware_sysinstall "@"
}

slackware_pkgtool_install_111() {
    . "$AUTOINST_D/install/pkgtool.sh"
    _slackware_pkgtool_install_111 "@"
}

slackware_pkgtool_install() {
    . "$AUTOINST_D/install/pkgtool.sh"
    _slackware_pkgtool_install "@"
}

sls_sysinstall() {
    . "$AUTOINST_D/install/sysinst.sh"
    _sls_sysinstall "@"
}

debian_install_base() {
    . "$AUTOINST_D/install/debian.sh"
    _debian_install_base "$@"
}

debian_install_packages_flat() {
    . "$AUTOINST_D/install/debian.sh"
    _debian_install_packages_flat "$@"
}

configure_networking() {
    . "$AUTOINST_D/config/net.sh"
    _configure_networking "$@"
}

configure_x11() {
    . "$AUTOINST_D/config/x11.sh"
    _configure_x11 "$@"
}

enable_serial_console() {
    . "$AUTOINST_D/config/tty.sh"
    _enable_serial_console "$@"
}

enable_serial_console() {
    . "$AUTOINST_D/config/tty.sh"
    _enable_serial_console "$@"
}

configure_mail() {
    . "$AUTOINST_D/config/mail.sh"
    _configure_mail "$@"
}