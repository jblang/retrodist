7z x $ORIGDIR/disc1.iso \
    bootdsks.144/idecd \
    rootdsks/color.gz > /dev/null
mv bootdsks.144/idecd boot.img
rmdir bootdsks.144
mv rootdsks/color.gz root.img
rmdir rootdsks
truncate -s 1440k boot.img root.img