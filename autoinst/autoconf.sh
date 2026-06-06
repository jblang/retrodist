#!/bin/sh
# Automatic configuration for retro distros
PATH=$PATH:/usr/bin:/bin:/etc:/usr/etc:/sbin:/usr/sbin
SCRIPTDIR=`echo "$0" | sed 's,/[^/]*$,,'`
if [ -z "$SCRIPTDIR" -o "$SCRIPTDIR" = "$0" ]; then
    SCRIPTDIR=.
fi
SCRIPTBASE=`basename "$0"`
SCRIPTNAME=`cd "$SCRIPTDIR" && pwd`/"$SCRIPTBASE"
INSTMOUNT=/retro

if [ ! -d "$INSTMOUNT" ]; then
    mkdir -p "$INSTMOUNT"
fi
mount -t msdos /dev/hdb1 "$INSTMOUNT"

# make sure an install scripts directory exists
AUTOINST_D="$INSTMOUNT/autoinst.d"
if [ ! -d "$AUTOINST_D" ]; then
    echo "No autoinst.d directory found; aborting."
    exit 1
fi

# define common helper functions
. "$AUTOINST_D/common.sh"
AUTOINST_DEBUG=${AUTOINST_DEBUG:-0}
AUTOINST_LOG=${AUTOINST_LOG:-/autoinst.log}
log_div
log_info "Retro Distro Playground Auto Configuration (autoconf.sh)"
log_info "Configuration paths:"
log_info "  INSTMOUNT=$INSTMOUNT"
log_info "  AUTOINST_D=$AUTOINST_D"
log_info "  SCRIPTNAME=$SCRIPTNAME"

# run distro-specific configuration
if [ -f "$AUTOINST_D/distro/autoconf.sh" ]; then
    . "$AUTOINST_D/distro/autoconf.sh"
else
    log_error "No distro-specific autoconf script found; aborting."
    exit 1
fi

log_div
log_info "Configuration complete!"
# prevent script from running again
rm -f "$SCRIPTNAME"
sync
reboot
