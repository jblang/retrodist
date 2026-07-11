# unzip files from source archive to correct directory
unzip -q "$DOWNLOAD_D/slackware.zip" -d "$TEMP_D"
mkdir -p "$TEMP_D/packages"
for ZIP in "$TEMP_D"/*.ZIP; do
  DISK=$(basename "$ZIP" .ZIP | sed 's/SK101//' | tr A-Z a-z)
  unzip -L -q "$ZIP" -d "$TEMP_D/packages/$DISK"
  rm "$ZIP"
done

# unzip files in A1 directory
for ZIP in "$TEMP_D"/packages/a1/*.zip; do
  unzip -L -q $ZIP -d "$TEMP_D/packages/a1"
  rm $ZIP
done

# Use IDE packages for the a2 set (a2s is SCSI)
mv "$TEMP_D/packages/a2i" "$TEMP_D/packages/a2"

# clean up some files that got put into the wrong dirs
for WRONGLABEL in "$TEMP_D"/packages/a*/diskx* "$TEMP_D"/packages/x*/diska*; do
  WRONG_D=$(dirname $WRONGLABEL)
  FILES=$(cat $WRONGLABEL | cut -d: -f1 | sort | uniq)
  for FILE in $FILES; do
    rm "$WRONG_D/$FILE.tgz"
  done
  rm "$WRONGLABEL"
done

# copy auto installation files
EXTRACT_BOOT_IMAGE=$TEMP_D/packages/a1/a1disk
EXTRACT_PACKAGES=$TEMP_D/packages
extract_install_files
rm -rf fat/install
mv fat/packages fat/install
