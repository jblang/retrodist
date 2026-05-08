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
if [ ! -d "$INSTMOUNT/autoinst.d" ]; then
    echo "No autoinst.d directory found; aborting."
    exit 1
fi

source_script_libraries() {
    for SCRIPTDIR in \
        "$INSTMOUNT/autoinst.d/common" \
        "$INSTMOUNT/autoinst.d/debian" \
        "$INSTMOUNT/autoinst.d/slakware"
    do
        if [ -d "$SCRIPTDIR" ]; then
            for SCRIPTFILE in $SCRIPTDIR/*.sh $SCRIPTDIR/*/*.sh; do
                if [ -f "$SCRIPTFILE" ]; then
                    . "$SCRIPTFILE"
                fi
            done
        fi
    done
}

if [ ! -f "$INSTMOUNT/autoinst.d/config/autoinst.sh" ]; then
    echo "No autoinst manifest found; aborting."
    exit 1
fi

source_script_libraries
. "$INSTMOUNT/autoinst.d/config/autoinst.sh"

echo "### Rebooting..."
echo "Press ENTER to reboot."
read line
sync
reboot
