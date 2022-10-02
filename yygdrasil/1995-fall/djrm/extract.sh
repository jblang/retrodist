7z x $ORIGDIR/disc1.iso \
    bootflop.3in > /dev/null
mv bootflop.3in boot.img
autoinst_prep 500M