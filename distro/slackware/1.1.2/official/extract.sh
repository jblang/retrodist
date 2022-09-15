#!/usr/bin/env bash
cp -lR $SLACKBASE/slackware-1.1.2 $CACHEDIR/install
cp $CACHEDIR/install/bootdisk/1_44meg/bareboot.gz $CACHEDIR/boot.img.gz
cp $CACHEDIR/install/bootdisk/1_44meg/color144.gz $CACHEDIR/root.img.gz
gunzip $CACHEDIR/boot.img.gz
gunzip $CACHEDIR/root.img.gz