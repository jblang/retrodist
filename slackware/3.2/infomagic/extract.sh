7z e $ORIGDIR/disc1.iso \
    bootdsks.144/bare.i \
    rootdsks/color.gz > /dev/null
mv bare.i boot.img
truncate -s1440k boot.img
mv color.gz root.img