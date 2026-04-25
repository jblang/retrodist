7z x $ORIGDIR/disc1.iso . \
    slakware \
    bootdsks.144/bare.i \
    rootdsks/text.gz > /dev/null
mv slakware install
mv bootdsks.144/bare.i boot.img
truncate -s1440k boot.img
rmdir bootdsks.144
mv rootdsks/text.gz root.img
rmdir rootdsks
autoinst_prep 2G