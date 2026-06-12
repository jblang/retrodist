#!/usr/bin/env bash

DISKDIR=bo/disks-i386/1997-05-30

7z e "$ORIGDIR/disc3.iso" \
    "$DISKDIR/base1_3.tgz" \
    "$DISKDIR/resc1440.bin" \
    "$DISKDIR/root.bin" \
    "$DISKDIR/drv1440.bin" > /dev/null

7z x -y "$ORIGDIR/disc3.iso" bo/msdos-i386 -oinstall > /dev/null
mv install/bo/msdos-i386 install/msdos-i386
rm -rf install/bo

cp -l "base1_3.tgz" install/
mv "resc1440.bin" boot.img
mv "root.bin" root.img
7z x -y -o. boot.img LINUX >/dev/null
mv -f LINUX kernel

mkdir -p install/bootflop
7z x -y -oinstall/bootflop boot.img LINUX INSTALL.SH RDEV.SH SYS_MAP.GZ TYPE.TXT >/dev/null
for FILE in install/bootflop/*; do
    LOWER=$(echo "$(basename "$FILE")" | tr '[:upper:]' '[:lower:]')
    if [ "$(basename "$FILE")" != "$LOWER" ]; then
        mv "$FILE" "install/bootflop/$LOWER"
    fi
done

mkdir -p install/drivers
7z x -y -oinstall/drivers drv1440.bin >/dev/null
for FILE in install/drivers/*; do
    LOWER=$(echo "$(basename "$FILE")" | tr '[:upper:]' '[:lower:]')
    if [ "$(basename "$FILE")" != "$LOWER" ]; then
        mv "$FILE" "install/drivers/$LOWER"
    fi
done
