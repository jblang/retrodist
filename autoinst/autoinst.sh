#!/bin/sh
# Automatic installation for retro distros
echo "### Beginning automatic installation..."

# figure out the source and dest mount points
if [ -d /target ]; then
    INSTMOUNT=/mnt
    ROOTMOUNT=/target
elif [ -d /var/adm/mount ]; then
    INSTMOUNT=/var/adm/mount
    ROOTMOUNT=/mnt
elif [ -d /root ]; then
    INSTMOUNT=/mnt
    ROOTMOUNT=/root
else
    echo "Unsupported installer layout; aborting."
    exit 1
fi

# make sure an install scripts directory exists
if [ ! -d "$INSTMOUNT/autoinst.d" ]; then
    echo "No autoinst.d directory found; aborting."
    exit 1
fi

# run each of the install scripts
. $INSTMOUNT/autoinst.d/config.sh
for INSTSTEP in $INSTMOUNT/autoinst.d/inststep/[0-9]*.sh; do
    . "$INSTSTEP"
done

echo "### Rebooting..."
echo "Press ENTER to reboot."
read line
sync
reboot
