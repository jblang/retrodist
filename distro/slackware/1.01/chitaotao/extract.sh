unzip -q $ORIG/slackware.zip -d $TEMPDIR
mkdir -p $CACHE/install/a1
mv $TEMPDIR/a1.img $CACHE/install/a1/a1disk
echo "Using sudo to mount disk images. Enter your password if prompted."
for IMG in $TEMPDIR/[atx]*.img; do
  DISK=$(basename $IMG .img)
  sudo mount $IMG /mnt
  cp -R /mnt $CACHE/install/$DISK
  sudo umount /mnt
  rm $IMG
done
find $CACHE -type f | xargs chmod -x
cp $CACHE/install/a1/a1disk $CACHE/boot.img