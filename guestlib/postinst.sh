#!/bin/sh
# Post-installation configuration runner.
ETC_D=/etc

GUESTLIB_D=/retro/guestlib.d
if [ ! -d "$GUESTLIB_D" ]; then
    echo "No guestlib.d directory found; aborting."
    exit 1
fi

# define common helper functions
. "$GUESTLIB_D/logging.sh"

# Load the module autoloading configurator.
mod_config() {
    POSTINST_REBOOT=true
    . "$GUESTLIB_D/config/modules.sh"
    _mod_config "$@"
}

# Load the network configurator.
net_config() {
    POSTINST_REBOOT=true
    . "$GUESTLIB_D/config/net.sh"
    _net_config "$@"
}

# Load the serial console configurator.
tty_config() {
    POSTINST_REBOOT=true
    . "$GUESTLIB_D/config/tty.sh"
    _tty_config "$@"
}

# Load the X11 configurator.
x11_config() {
    . "$GUESTLIB_D/config/x11.sh"
    _x11_config "$@"
}

POSTINST_DEBUG=${POSTINST_DEBUG:-0}
POSTINST_LOG=${POSTINST_LOG:-/postinst.log}
POSTINST_REBOOT=${POSTINST_REBOOT:-false}
log_div
log INFO "Post-Installation Configuration (postinst.sh)"
log INFO "Configuration paths:"
log INFO "  GUESTLIB_D=$GUESTLIB_D"

# run distro-specific configuration
if [ -f "$GUESTLIB_D/distro/postinst.sh" ]; then
    . "$GUESTLIB_D/distro/postinst.sh"
else
    log ERROR "No distro-specific postinst script found; aborting."
    exit 1
fi

log_div
log INFO "Configuration complete!"
sync
case "$POSTINST_REBOOT" in
    true|TRUE|True|yes|YES|Yes|1)
        reboot
        ;;
esac
