7z x $ORIGDIR/disc1.iso . \
    slakware \
    bootdsks.144/idecd \
    rootdsks.144/tty144 > /dev/null
mv slakware install
mv bootdsks.144/idecd boot.img
rmdir bootdsks.144
mv rootdsks.144/tty144 root.img
rmdir rootdsks.144
autoinst_prep 2G