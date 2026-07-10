unzip -q "$ORIGDIR/slackware.zip" -d "$TEMPDIR"

for IMG in "$TEMPDIR"/[atx]*.img; do
  DISK=$(basename "$IMG" .img)
  if [[ "$DISK" != "a1" ]]; then
    mkdir -p "$TEMPDIR/packages/$DISK"
    7z x -y -o"$TEMPDIR/packages/$DISK" "$IMG" >/dev/null
  fi
done

EXTRACT_BOOT_IMAGE=$TEMPDIR/a1.img
EXTRACT_PACKAGES=$TEMPDIR/packages
extract_install_files
rm -rf fat/install
mv fat/packages fat/install
