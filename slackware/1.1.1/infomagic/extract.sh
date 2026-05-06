7z x $ORIGDIR/disc1.iso sunsite/distributions/slackware > /dev/null
mkdir -p install
mv sunsite/distributions/slackware install/slakware
rm -rf sunsite
cp install/slakware/bootdisk/1_44meg/uniboot boot.img
# 1.1.1 x_svga.tgz has CRC error, so borrow working package from 1.1.2
cp $ORIGDIR/x_svga.tgz install/slakware/x2/x_svga.tgz
