unzip -q $ORIG/slackware.zip -d $TEMPDIR
mkdir -p $CACHE/install
mv $TEMPDIR/a1.img $CACHE
echo "Using sudo to mount disk images. Enter your password if prompted."
for IMG in $TEMPDIR/[atx]*.img; do
  DISK=$(basename $IMG .img)
  sudo mount $IMG /mnt
  cp -R /mnt $CACHE/install/$DISK
  sudo umount /mnt
  rm $IMG
done
find $CACHE -type f | xargs chmod -x
