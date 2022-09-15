unzip -q $ORIGDIR/slackware.zip -d $TEMPDIR
mkdir -p $CACHEDIR/install/install/a1
mv $TEMPDIR/a1.img $CACHEDIR/install/install/a1/a1disk
echo "Using sudo to mount disk images. Enter your password if prompted."
for IMG in $TEMPDIR/[atx]*.img; do
  DISK=$(basename $IMG .img)
  sudo mount $IMG /mnt
  cp -R /mnt $CACHEDIR/install/install/$DISK
  sudo umount /mnt
  rm $IMG
done
find $CACHEDIR -type f | xargs chmod -x
cp $CACHEDIR/install/install/a1/a1disk $CACHEDIR/boot.img