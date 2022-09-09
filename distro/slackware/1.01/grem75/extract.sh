# unzip files from source archive to correct directory
unzip -q $ORIG/slackware.zip -d $CACHE
mkdir -p $CACHE/install
for ZIP in $CACHE/*.ZIP; do
  DISK=$(basename $ZIP .ZIP | sed 's/SK101//' | tr A-Z a-z)
  unzip -L -q $ZIP -d $CACHE/install/$DISK
  rm $ZIP
done

# unzip files in A1 directory
for ZIP in $CACHE/install/a1/*.zip; do
  unzip -L -q $ZIP -d $CACHE/install/a1
  rm $ZIP
done
mv $CACHE/install/a2i $CACHE/install/a2
cp $CACHE/install/a1/a1disk $CACHE/a1.img

# clean up some files that got put into the wrong dirs
WRONGDISKS=$(ls $CACHE/install/a*/diskx* $CACHE/install/x*/diska*)
for WRONG in $WRONGDISKS; do
  WRONGDIR=$(dirname $WRONG)
  NEWDIR=$CACHE/install/$(basename $WRONG | sed "s/disk//")b
  mkdir -p $NEWDIR
  FILES=$(cat $WRONG | cut -d: -f1 | sort | uniq)
  for FILE in $FILES; do
    mv $WRONGDIR/$FILE.tgz $NEWDIR
  done
  mv $WRONG $NEWDIR
done