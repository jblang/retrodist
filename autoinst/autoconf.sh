#!/bin/sh
# Automatic configuration for retro distros
echo "### Beginning automatic configuration..."
PATH=$PATH:/usr/bin:/bin:/sbin:/usr/sbin
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
if [ ! -d "$INSTMOUNT/autoinst.d" ]; then
    echo "No autoinst.d directory found; aborting."
    exit 1
fi

# run the install scripts
. $INSTMOUNT/autoinst.d/config.sh
for CONFSTEP in $INSTMOUNT/autoinst.d/confstep/[0-9]*.sh; do
    . "$CONFSTEP"
done

echo "### Rebooting"
# prevent script from running again
rm -f $SCRIPTNAME
sync
reboot
