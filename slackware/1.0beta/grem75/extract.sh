mkdir -p install
tar xfz $ORIGDIR/slackware.tar.gz
mv slack-pre1.0 install/install
mkdir -p install/install/a1
mv install/install/a1.img install/install/a1/a1disk
cp install/install/a1/a1disk boot.img
autoinst_prep 500M