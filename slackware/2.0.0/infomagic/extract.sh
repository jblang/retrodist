mount_copy $ORIGDIR/disc1.iso . \
    /slakware \
    /slakinst/boot144/bare \
    /slakinst/root144/color144
mv slakware install
mv bare boot.img
mv color144 root.img