#!/bin/sh
# Automatic configuration for retro distros
echo "### Beginning automatic configuration..."
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

if [ ! -f "$INSTMOUNT/autoinst.d/config/autoconf.sh" ]; then
    echo "No autoconf manifest found; aborting."
    exit 1
fi

source_script_libraries
. "$INSTMOUNT/autoinst.d/config/autoconf.sh"

echo "### Rebooting"
# prevent script from running again
rm -f $SCRIPTNAME
sync
reboot
