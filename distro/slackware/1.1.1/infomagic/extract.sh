SOURCE=cdrom/infomagic/ldr/1993_12
echo $PWD $SOURCE
(cd $SCRIPTDIR; ./extract.sh $SOURCE)
cp -lR $CACHEBASE/$SOURCE/disc1/sunsite/distributions/slackware/* $CACHE
cp $CACHE/bootdisk/1_44meg/uniboot $CACHE/boot.img