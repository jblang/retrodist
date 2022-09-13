SOURCE=cdrom/infomagic/ldr/1993_12
(cd $SCRIPTDIR; ./extract.sh $SOURCE)
cp -lR $CACHEBASE/$SOURCE/disc1/sunsite/distributions/slackware/* $CACHE
cp $CACHE/bootdisk/1_44meg/uniboot $CACHE/boot.img
# 1.1.1 x_svga.tgz has CRC error, so borrow working package from 1.1.2
SOURCE112=distro/slackware/1.1.2/official
(cd $SCRIPTDIR; ./extract.sh $SOURCE112)
cp $CACHEBASE/distro/slackware/1.1.2/official/x2/x_svga.tgz $CACHE/x2/x_svga.tgz