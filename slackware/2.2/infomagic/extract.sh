7z x $ORIGDIR/disc1.iso \
    slakware \
    slakinst/boot144/idecd \
    slakinst/root144/tty144 > /dev/null
mv slakware install
mv slakinst/boot144/idecd boot.img
mv slakinst/root144/tty144 root.img
rm -rf slakinst
autoinst_prep 2G