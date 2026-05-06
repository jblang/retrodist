7z e $ORIGDIR/disc1.iso \
    bootdsks.144/idecd \
    rootdsks/color.gz > /dev/null
mv idecd boot.img
truncate -s1440k boot.img
mv color.gz root.img
