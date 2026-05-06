7z e $ORIGDIR/disc1.iso . \
    bootdsks.144/idecd \
    rootdsks.144/color144 > /dev/null
mv idecd boot.img
mv color144 root.img