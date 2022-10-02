7z x $ORIGDIR/disc1.iso \
    distributions/slackware \
    distributions/slakinst/boot144/bare.gz \
    distributions/slakinst/root144/color144.gz > /dev/null
mv distributions/slackware install
mv distributions/slakinst/boot144/bare.gz boot.img.gz
mv distributions/slakinst/root144/color144.gz root.img.gz
rm -rf distributions
gunzip *.gz