unzip -q $ORIGDIR/slackware.zip -d $TEMPDIR
mkdir -p install/install/a1
mv $TEMPDIR/a1.img install/install/a1/a1disk
for IMG in $TEMPDIR/[atx]*.img; do
  DISK=$(basename $IMG .img)
  7z x $IMG -oinstall/install/$DISK > /dev/null
done
cp install/install/a1/a1disk boot.img
autoinst_prep 500M