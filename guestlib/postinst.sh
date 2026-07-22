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
# shellcheck disable=SC2120 # Public wrappers accept optional helper arguments.
mod_config() {
    POSTINST_REBOOT=true
    . "$GUESTLIB_D/config/modules.sh"
    _mod_config "$@"
}

# Load the network configurator.
# shellcheck disable=SC2120 # Public wrappers accept optional helper arguments.
net_config() {
    POSTINST_REBOOT=true
    . "$GUESTLIB_D/config/net.sh"
    _net_config "$@"
}

# Load the serial console configurator.
# shellcheck disable=SC2120 # Public wrappers accept optional helper arguments.
tty_config() {
    POSTINST_REBOOT=true
    . "$GUESTLIB_D/config/tty.sh"
    _tty_config "$@"
}

# Load the X11 configurator.
# shellcheck disable=SC2120 # Public wrappers accept optional helper arguments.
x11_config() {
    . "$GUESTLIB_D/config/x11.sh"
    _x11_config "$@"
}

if [ -f "$GUESTLIB_D/distro/config.sh" ]; then
    . "$GUESTLIB_D/distro/config.sh"
fi

POSTINST_DEBUG=${POSTINST_DEBUG:-0}
POSTINST_LOG=${POSTINST_LOG:-/postinst.log}
POSTINST_REBOOT=${POSTINST_REBOOT:-false}
log_div
log INFO "Post-Installation Configuration (postinst.sh)"
log INFO "Configuration paths:"
log INFO "  GUESTLIB_D=$GUESTLIB_D"

# Run the stages rendered from the distro's declarative TOML configuration.
if [ -z "${POSTINST_STAGES:-}" ]; then
    log ERROR "No declarative post-install stages found; aborting."
    exit 1
fi
for POSTINST_STAGE in $POSTINST_STAGES; do
    # shellcheck disable=SC2119 # Declarative stages intentionally pass no arguments.
    case "$POSTINST_STAGE" in
        packages)
            if [ ! -f "$GUESTLIB_D/distro/packages.sh" ]; then
                log ERROR "Package stage has no generated packages.sh; aborting."
                exit 1
            fi
            . "$GUESTLIB_D/distro/packages.sh"
            ;;
        modules) mod_config ;;
        network) net_config ;;
        tty) tty_config ;;
        x11) x11_config ;;
        custom)
            if [ ! -f "$GUESTLIB_D/distro/postinst.sh" ]; then
                log ERROR "Custom post-install stage has no postinst.sh; aborting."
                exit 1
            fi
            . "$GUESTLIB_D/distro/postinst.sh"
            ;;
        *)
            log ERROR "Unknown post-install stage: $POSTINST_STAGE"
            exit 1
            ;;
    esac
done

log_div
log INFO "Configuration complete!"
sync
case "$POSTINST_REBOOT" in
    true|TRUE|True|yes|YES|Yes|1)
        reboot
        ;;
esac
