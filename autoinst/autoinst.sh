#!/bin/sh
# Automatic installation for retro distros
PATH=$PATH:/usr/bin:/bin:/etc:/usr/etc:/sbin:/usr/sbin:/usr/lib/setup

# Derive the staged media mount point from the script location so installs
# work no matter where the FAT disk is mounted.
case "$0" in
    */*) SCRIPTDIR=$(echo "$0" | sed 's,/[^/]*$,,') ;;
    *) SCRIPTDIR=. ;;
esac
INSTMOUNT=$(cd "$SCRIPTDIR" && pwd)

# figure out the destination mount point
if [ -d /target ]; then
    ROOTMOUNT=/target
elif [ -d /var/adm/mount ]; then
    ROOTMOUNT=/mnt
elif [ -d /root ]; then
    ROOTMOUNT=/root
else
    echo "Unsupported installer layout; aborting."
    exit 1
fi

# make sure an install scripts directory exists
AUTOINST_D="$INSTMOUNT/autoinst.d"
if [ ! -d "$AUTOINST_D" ]; then
    echo "No autoinst.d directory found; aborting."
    exit 1
fi

# define common helper functions
. "$AUTOINST_D/common.sh"
AUTOINST_DEBUG=${AUTOINST_DEBUG:-0}
AUTOINST_LOG=${AUTOINST_LOG:-${TMPDIR:-/tmp}/autoinst.log}
: >"$AUTOINST_LOG"
log_div
log_info "Retro Distro Playground Auto Installation (autoinst.sh)"
log_info "Installation paths:"
log_info "  INSTMOUNT=$INSTMOUNT"
log_info "  ROOTMOUNT=$ROOTMOUNT"
log_info "  AUTOINST_D=$AUTOINST_D"

# run distro-specific installation
if [ -f "$AUTOINST_D/distro/autoinst.sh" ]; then
    . "$AUTOINST_D/distro/autoinst.sh"
else
    log_error "No distro-specific autoinst script found; aborting."
    exit 1
fi

log_div
log_info "Installation complete!"
log_info "Copying installation log to $ROOTMOUNT/autoinst.log"
cat "$AUTOINST_LOG" >"$ROOTMOUNT/autoinst.log"
log_attention "Press ENTER to reboot."
read line
sync
reboot
