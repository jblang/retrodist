#!/bin/sh
# Automatic configuration for retro distros
echo "### Beginning automatic configuration..."
PATH=$PATH:/usr/bin:/bin:/sbin:/usr/sbin
SCRIPTNAME=$(cd $(dirname $0) && pwd)/$(basename $0)
INSTMOUNT=/mnt

mount -t msdos /dev/hdb1 $INSTMOUNT

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