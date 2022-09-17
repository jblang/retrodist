mount_copy $ORIGDIR/disc1.iso . \
    /distributions/slackware \
    /distributions/slakinst/boot144/bare.gz \
    /distributions/slakinst/root144/color144.gz
mv slackware install
gunzip *.gz
mv bare boot.img
mv color144 root.img