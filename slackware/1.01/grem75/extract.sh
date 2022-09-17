# unzip files from source archive to correct directory
unzip -q $ORIGDIR/slackware.zip
mkdir -p install/install
for ZIP in *.ZIP; do
  DISK=$(basename $ZIP .ZIP | sed 's/SK101//' | tr A-Z a-z)
  unzip -L -q $ZIP -d install/install/$DISK
  rm $ZIP
done

# unzip files in A1 directory
for ZIP in install/install/a1/*.zip; do
  unzip -L -q $ZIP -d install/install/a1
  rm $ZIP
done
mv install/install/a2i install/install/a2
cp install/install/a1/a1disk boot.img

# clean up some files that got put into the wrong dirs
WRONGDISKS=$(ls install/install/a*/diskx* install/install/x*/diska*)
for WRONG in $WRONGDISKS; do
  WRONGDIR=$(dirname $WRONG)
  NEWDIR=install/install/$(basename $WRONG | sed "s/disk//")b
  mkdir -p $NEWDIR
  FILES=$(cat $WRONG | cut -d: -f1 | sort | uniq)
  for FILE in $FILES; do
    mv $WRONGDIR/$FILE.tgz $NEWDIR
  done
  mv $WRONG $NEWDIR
done