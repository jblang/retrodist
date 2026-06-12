#!/usr/bin/env bash

7z e $ORIGDIR/disc3.iso \
    buzz-updates/disks-i386/1996_7_14/base1_1.tgz \
    buzz-updates/disks-i386/1996_7_14/boot1440.bin \
    buzz-updates/disks-i386/1996_7_14/root.bin > /dev/null

mkdir -p install
cp -l "base1_1.tgz" install/
mv "boot1440.bin" boot.img
mv "root.bin" root.img

mkdir -p install/bootflop
7z x -y -oinstall/bootflop boot.img LINUX INSTALL.SH RDEV.SH SYS_MAP.GZ MODULES.TGZ >/dev/null
for FILE in install/bootflop/*; do
    LOWER=$(echo "$(basename "$FILE")" | tr '[:upper:]' '[:lower:]')
    if [ "$(basename "$FILE")" != "$LOWER" ]; then
        mv "$FILE" "install/bootflop/$LOWER"
    fi
done