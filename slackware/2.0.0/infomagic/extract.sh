7z x $ORIGDIR/disc1.iso \
    slakware \
    slakinst/boot144/bare \
    slakinst/root144/color144 > /dev/null
mv slakware install
mv slakinst/boot144/bare boot.img
mv slakinst/root144/color144 root.img
rm -rf slakinst