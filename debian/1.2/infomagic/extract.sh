#!/usr/bin/env bash

7z e $ORIGDIR/disc3.iso \
    rex-updates/disks-i386/1997-01-18/base1_2.tgz \
    rex-updates/disks-i386/1997-01-18/rsc1440.bin \
    rex-updates/disks-i386/1997-01-18/root.bin > /dev/null

mkdir -p install
cp -l "base1_2.tgz" install/
mv "rsc1440.bin" boot.img
mv "root.bin" root.img

mkdir -p install/bootflop
7z x -y -oinstall/bootflop boot.img LINUX INSTALL.SH RDEV.SH SYS_MAP.GZ MODULES.TGZ >/dev/null
for FILE in install/bootflop/*; do
    LOWER=$(echo "$(basename "$FILE")" | tr '[:upper:]' '[:lower:]')
    if [ "$(basename "$FILE")" != "$LOWER" ]; then
        mv "$FILE" "install/bootflop/$LOWER"
    fi
done