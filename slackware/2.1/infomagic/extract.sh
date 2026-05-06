7z x $ORIGDIR/disc1.iso \
    distributions/slackware \
    distributions/slakinst/boot144/bare \
    distributions/slakinst/root144/color144 > /dev/null
mkdir -p install
mv distributions/slackware install/slakware
mv distributions/slakinst/boot144/bare boot.img
mv distributions/slakinst/root144/color144 root.img
rm -rf distributions
