SOURCE=$SLACKBASE/slackware-1.01
mkdir -p $CACHE/install
cp -R $SOURCE/[ax][0-9]* $CACHE/install
mv $CACHE/install/a1/a1disk $CACHE/a1.img