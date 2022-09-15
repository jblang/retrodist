mkdir -p $CACHEDIR/install
tar xfz $ORIGDIR/slackware.tar.gz -C $CACHEDIR
mv $CACHEDIR/slack-pre1.0 $CACHEDIR/install/install
mkdir -p $CACHEDIR/install/install/a1
mv $CACHEDIR/install/install/a1.img $CACHEDIR/install/install/a1/a1disk
cp $CACHEDIR/install/install/a1/a1disk $CACHEDIR/boot.img