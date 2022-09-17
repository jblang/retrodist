INSTROOT=/sunsite/distributions/slackware
mount_copy $ORIGDIR/disc1.iso . \
    $INSTROOT \
    $INSTROOT/bootdisk/1_44meg/uniboot
mv slackware install
mv uniboot boot.img
# 1.1.1 x_svga.tgz has CRC error, so borrow working package from 1.1.2
cp $ORIGDIR/x_svga.tgz install/x2/x_svga.tgz