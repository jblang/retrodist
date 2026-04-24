#!/usr/bin/env bash

RELBASE=$DEBIANBASE/Debian-0.93R6
DISKDIR=$RELBASE/disks

cp -lR "$RELBASE/ms-dos" install

gzip -dc "$DISKDIR/1440_boot_floppy.gz" > boot.img
gzip -dc "$DISKDIR/1440_root_floppy.gz" > root.img
cp "$DISKDIR"/1440_base_floppy-* .

ln -sf ../1440_base_floppy-1 install/basedsk1.img
ln -sf ../1440_base_floppy-2 install/basedsk2.img
ln -sf ../1440_base_floppy-3 install/basedsk3.img

autoinst_prep 500M
