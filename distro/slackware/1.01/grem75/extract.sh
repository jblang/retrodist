# unzip files from source archive to correct directory
unzip -q $ORIGDIR/slackware.zip -d $CACHEDIR
mkdir -p $CACHEDIR/install/install
for ZIP in $CACHEDIR/*.ZIP; do
  DISK=$(basename $ZIP .ZIP | sed 's/SK101//' | tr A-Z a-z)
  unzip -L -q $ZIP -d $CACHEDIR/install/install/$DISK
  rm $ZIP
done

# unzip files in A1 directory
for ZIP in $CACHEDIR/install/install/a1/*.zip; do
  unzip -L -q $ZIP -d $CACHEDIR/install/install/a1
  rm $ZIP
done
mv $CACHEDIR/install/install/a2i $CACHEDIR/install/install/a2
cp $CACHEDIR/install/install/a1/a1disk $CACHEDIR/boot.img

# clean up some files that got put into the wrong dirs
WRONGDISKS=$(ls $CACHEDIR/install/install/a*/diskx* $CACHEDIR/install/install/x*/diska*)
for WRONG in $WRONGDISKS; do
  WRONGDIR=$(dirname $WRONG)
  NEWDIR=$CACHEDIR/install/install/$(basename $WRONG | sed "s/disk//")b
  mkdir -p $NEWDIR
  FILES=$(cat $WRONG | cut -d: -f1 | sort | uniq)
  for FILE in $FILES; do
    mv $WRONGDIR/$FILE.tgz $NEWDIR
  done
  mv $WRONG $NEWDIR
done