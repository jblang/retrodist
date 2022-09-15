SOURCE=$SLACKBASE/slackware-1.01
mkdir -p $CACHEDIR/install/install
cp -R $SOURCE/[ax][0-9]* $CACHEDIR/install/install
cp $CACHEDIR/install/install/a1/a1disk $CACHEDIR/boot.img