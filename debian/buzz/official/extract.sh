#!/usr/bin/env bash

BUZZBASE=$DEBIANBASE/buzz/main
DISKDIR=$BUZZBASE/disks-i386/1996_6_16

cp -lR "$BUZZBASE/msdos-i386" install
cp -l "$DISKDIR/base1_1.tgz" install/

cp "$DISKDIR/boot1440.bin" boot.img
cp "$DISKDIR/root.bin" root.img
mkdir -p install/bootflop
7z x -y -oinstall/bootflop boot.img LINUX INSTALL.SH RDEV.SH SYS_MAP.GZ MODULES.TGZ >/dev/null
for FILE in install/bootflop/*; do
    LOWER=$(echo "$(basename "$FILE")" | tr '[:upper:]' '[:lower:]')
    if [ "$(basename "$FILE")" != "$LOWER" ]; then
        mv "$FILE" "install/bootflop/$LOWER"
    fi
done
cp "$DISKDIR"/base14-*.bin .

ln -sf ../base14-1.bin install/basedsk1.img
ln -sf ../base14-2.bin install/basedsk2.img
ln -sf ../base14-3.bin install/basedsk3.img
