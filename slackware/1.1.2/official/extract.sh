#!/usr/bin/env bash
mkdir -p install
cp -lR $SLACKBASE/slackware-1.1.2 install/slakware
cp install/slakware/bootdisk/1_44meg/bareboot.gz boot.img.gz
cp install/slakware/bootdisk/1_44meg/color144.gz root.img.gz
gunzip boot.img.gz
gunzip root.img.gz
