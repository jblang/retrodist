mount_copy $ORIGDIR/disc1.iso . \
    bootdsks.144/bare.i \
    rootdsks/color.gz
mv bare.i boot.img
mv color.gz root.img
truncate -s 1440k boot.img root.img