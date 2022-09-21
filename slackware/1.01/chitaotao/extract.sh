unzip -q $ORIGDIR/slackware.zip -d $TEMPDIR
mkdir -p install/install/a1
mv $TEMPDIR/a1.img install/install/a1/a1disk
echo "Using sudo to mount disk images. Enter your password if prompted."
for IMG in $TEMPDIR/[atx]*.img; do
  DISK=$(basename $IMG .img)
  mount_copy $IMG install/install/$DISK
done
cp install/install/a1/a1disk boot.img
autoinst_prep 500M