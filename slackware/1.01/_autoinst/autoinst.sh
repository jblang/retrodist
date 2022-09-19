#!/bin/sh
# Automatic installation for retro distros
echo "# automatic installation"

# run installation scripts
if [ -d /var/adm/mount/install.d ]; then
    AUTOINST=/var/adm/mount/install.d
elif [ -d /mnt/install.d ]; then
    AUTOINST=/mnt/install.d
fi

for INSTFILE in $AUTOINST/[0-9]*.sh; do
    . "$INSTFILE"
done
