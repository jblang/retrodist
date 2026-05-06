#!/bin/sh
# Automatic installation for retro distros
echo "### Beginning automatic installation..."
PATH=$PATH:/usr/bin:/bin:/sbin:/usr/sbin:/usr/lib/setup

# Derive the staged media mount point from the script location so installs
# work no matter where the FAT disk is mounted.
case "$0" in
    */*) SCRIPTDIR=`echo "$0" | sed 's,/[^/]*$,,'` ;;
    *) SCRIPTDIR=. ;;
esac
INSTMOUNT=`cd "$SCRIPTDIR" && pwd`

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
