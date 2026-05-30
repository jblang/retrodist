#!/bin/sh
# Automatic installation for retro distros
echo "### Beginning automatic installation..."
PATH=$PATH:/usr/bin:/bin:/etc:/usr/etc:/sbin:/usr/sbin:/usr/lib/setup

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
AUTOINST_D="$INSTMOUNT/autoinst.d"
if [ ! -d "$AUTOINST_D" ]; then
    echo "No autoinst.d directory found; aborting."
    exit 1
fi

# define common helper functions
. "$AUTOINST_D/common.sh"

# run distro-specific installation
if [ -f "$AUTOINST_D/distro/autoinst.sh" ]; then
    . "$AUTOINST_D/distro/autoinst.sh"
else
    echo "No distro-specific autoinst script found; aborting."
    exit 1
fi

echo "### Rebooting..."
echo "Press ENTER to reboot."
read line
sync
reboot
