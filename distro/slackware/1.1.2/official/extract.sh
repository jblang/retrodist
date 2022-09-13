#!/usr/bin/env bash
SOURCE=$SLACKBASE/slackware-1.1.2
cp -lR $SOURCE/* $CACHE
cp $CACHE/bootdisk/1_44meg/bareboot.gz $CACHE/boot.img.gz
gunzip $CACHE/boot.img.gz
cp $CACHE/bootdisk/1_44meg/color144.gz $CACHE/root.img.gz
gunzip $CACHE/root.img.gz
