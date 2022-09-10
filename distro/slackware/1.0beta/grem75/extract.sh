tar xfz $ORIG/slackware.tar.gz -C $CACHE
mv $CACHE/slack-pre1.0 $CACHE/install
mkdir -p $CACHE/install/a1
mv $CACHE/install/a1.img $CACHE/install/a1/a1disk
cp $CACHE/install/a1/a1disk $CACHE/boot.img
ls $CACHE