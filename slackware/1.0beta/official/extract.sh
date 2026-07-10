cp -pR $SLACKBASE/slackware-pre-1.0-beta "$TEMPDIR/packages"
mkdir -p "$TEMPDIR/packages/a1"
mv "$TEMPDIR/packages/diska01" "$TEMPDIR/packages/a1/a1disk"
for DISK in "$TEMPDIR"/packages/diska*; do
  NUM=$(basename "$DISK" | sed 's/diska0*//')
  if [[ -d "$DISK" ]]; then
    mv "$DISK" "$TEMPDIR/packages/a$NUM"
  fi
done
EXTRACT_BOOT_IMAGE=$TEMPDIR/packages/a1/a1disk
EXTRACT_PACKAGES=$TEMPDIR/packages
extract_install_files
rm -rf fat/install
mv fat/packages fat/install
