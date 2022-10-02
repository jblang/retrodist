7z x $ORIGDIR/disc1.iso \
    slakinst/boot144/idecd \
    slakinst/root144/color144 > /dev/null
mv slakinst/boot144/idecd boot.img
mv slakinst/root144/color144 root.img
rm -rf slakinst
truncate -s 1440k boot.img root.img