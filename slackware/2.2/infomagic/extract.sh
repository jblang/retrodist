7z e $ORIGDIR/disc1.iso \
    slakinst/boot144/idecd \
    slakinst/root144/color144 > /dev/null
mv idecd boot.img
mv color144 root.img