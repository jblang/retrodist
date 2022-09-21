SOURCE=$SLACKBASE/slackware-1.01
mkdir -p install/install
cp -lR $SOURCE/[ax][0-9]* install/install
cp install/install/a1/a1disk boot.img
autoinst_prep 500M