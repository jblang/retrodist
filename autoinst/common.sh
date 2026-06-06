# common scripts
. "$AUTOINST_D/logging.sh"
. "$AUTOINST_D/diskutil.sh"

# helper functions that load helper scripts
slackware_sysinstall() {
    . "$AUTOINST_D/install/sysinst.sh"
    _slackware_sysinstall "$@"
}

slackware_pkgtool_install_111() {
    . "$AUTOINST_D/install/pkgtool.sh"
    _slackware_pkgtool_install_111 "$@"
}

slackware_pkgtool_install() {
    . "$AUTOINST_D/install/pkgtool.sh"
    _slackware_pkgtool_install "$@"
}

sls_sysinstall() {
    . "$AUTOINST_D/install/sysinst.sh"
    _sls_sysinstall "$@"
}

debian_install_base() {
    . "$AUTOINST_D/install/debian.sh"
    _debian_install_base "$@"
}

debian_091_install_base() {
    . "$AUTOINST_D/install/deb091.sh"
    _debian_091_install_base "$@"
}

debian_091_install_packages() {
    . "$AUTOINST_D/install/deb091.sh"
    _debian_091_install_packages "$@"
}

net_config() {
    . "$AUTOINST_D/config/net.sh"
    _net_config "$@"
}

x11_config() {
    . "$AUTOINST_D/config/x11.sh"
    _x11_config "$@"
}

tty_config() {
    . "$AUTOINST_D/config/tty.sh"
    _tty_config "$@"
}

configure_mail() {
    . "$AUTOINST_D/config/mail.sh"
    _configure_mail "$@"
}
