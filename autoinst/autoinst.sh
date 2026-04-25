#!/bin/sh
# Automatic installation for retro distros
echo "### Beginning automatic installation..."

# figure out the source and dest mount points
if [ -d /target ]; then
    SOURCEMOUNT=/mnt
    TARGETMOUNT=/target
elif [ -d /var/adm/mount ]; then
    SOURCEMOUNT=/mnt
    TARGETMOUNT=/target
    if [ ! -L /var/adm/mount ]; then
        rmdir /var/adm/mount 2>/dev/null
        ln -sf $TARGETMOUNT /var/adm/mount
    fi
elif [ -d /root ]; then
    SOURCEMOUNT=/mnt
    TARGETMOUNT=/root
else
    echo "Unsupported installer layout; aborting."
    exit 1
fi
mkdir -p $SOURCEMOUNT
mkdir -p $TARGETMOUNT

# mount the install source
mount -t msdos /dev/hdb1 $SOURCEMOUNT

# make sure an install scripts directory exists
if [ ! -d "$SOURCEMOUNT/autoinst.d" ]; then
    echo "No autoinst.d directory found; aborting."
    exit 1
fi

# run each of the install scripts
. $SOURCEMOUNT/autoinst.d/config.sh
for INSTSTEP in $SOURCEMOUNT/autoinst.d/inststep/[0-9]*.sh; do
    . "$INSTSTEP"
done

echo "### Rebooting..."
echo "Press ENTER to reboot."
read line
sync
reboot
