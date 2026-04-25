7z x $ORIGDIR/disc1.iso . \
    bootdsks.144/idecd \
    rootdsks.144/tty144 > /dev/null
mv bootdsks.144/idecd boot.img
rmdir bootdsks.144
mv rootdsks.144/tty144 root.img
rmdir rootdsks.144
truncate -s 1440k boot.img root.img
