# unzip files from source archive to correct directory
unzip -q "$ORIGDIR/slackware.zip" -d "$TEMPDIR"
mkdir -p "$TEMPDIR/packages"
for ZIP in "$TEMPDIR"/*.ZIP; do
  DISK=$(basename "$ZIP" .ZIP | sed 's/SK101//' | tr A-Z a-z)
  unzip -L -q "$ZIP" -d "$TEMPDIR/packages/$DISK"
  rm "$ZIP"
done

# unzip files in A1 directory
for ZIP in "$TEMPDIR"/packages/a1/*.zip; do
  unzip -L -q $ZIP -d "$TEMPDIR/packages/a1"
  rm $ZIP
done

# Use IDE packages for the a2 set (a2s is SCSI)
mv "$TEMPDIR/packages/a2i" "$TEMPDIR/packages/a2"

# clean up some files that got put into the wrong dirs
for WRONGLABEL in "$TEMPDIR"/packages/a*/diskx* "$TEMPDIR"/packages/x*/diska*; do
  WRONGDIR=$(dirname $WRONGLABEL)
  FILES=$(cat $WRONGLABEL | cut -d: -f1 | sort | uniq)
  for FILE in $FILES; do
    rm "$WRONGDIR/$FILE.tgz"
  done
  rm "$WRONGLABEL"
done

# copy auto installation files
EXTRACT_BOOT_IMAGE=$TEMPDIR/packages/a1/a1disk
EXTRACT_PACKAGES=$TEMPDIR/packages
extract_install_files
