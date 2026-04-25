7z x $ORIGDIR/disc1.iso \
    distributions/slackware \
    distributions/slakinst/boot144/bare \
    distributions/slakinst/root144/tty144 > /dev/null
mv distributions/slackware install
mv distributions/slakinst/boot144/bare boot.img
mv distributions/slakinst/root144/tty144 root.img
rm -rf distributions
autoinst_prep 500M
