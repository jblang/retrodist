#!/usr/bin/env bash
cp -lR $SLACKBASE/slackware-1.1.2 install
cp install/bootdisk/1_44meg/bareboot.gz boot.img.gz
cp install/bootdisk/1_44meg/color144.gz root.img.gz
gunzip boot.img.gz
gunzip root.img.gz