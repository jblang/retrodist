#!/usr/bin/env bash

REXBASE=$DEBIANBASE/rex/main
DISKDIR=$REXBASE/disks-i386/current

cp -lR "$REXBASE/msdos-i386" install
cp -l "$DISKDIR/base1_2.tgz" install/

cp "$DISKDIR/resq1440.bin" boot.img
cp "$DISKDIR/root.bin" root.img
7z x -y -o. boot.img LINUX >/dev/null
mv -f LINUX kernel
mkdir -p install/drivers
7z x -y -oinstall/drivers "$DISKDIR/drv1440.bin" >/dev/null
for FILE in install/drivers/*; do
    LOWER=$(echo "$(basename "$FILE")" | tr '[:upper:]' '[:lower:]')
    if [ "$(basename "$FILE")" != "$LOWER" ]; then
        mv "$FILE" "install/drivers/$LOWER"
    fi
done
cp "$DISKDIR"/base14-*.bin .

ln -sf ../base14-1.bin install/basedsk1.img
ln -sf ../base14-2.bin install/basedsk2.img
ln -sf ../base14-3.bin install/basedsk3.img
ln -sf ../base14-4.bin install/basedsk4.img

autoinst_prep 500M
