# unzip files from source archive to correct directory
unzip -q "$ORIGDIR/sls-1992.11.zip" -d "$TEMPDIR"
mkdir -p "$TEMPDIR/packages"
for ZIP in "$TEMPDIR"/SLS-1992.11/*.ZIP; do
  DISK=$(basename "$ZIP" .ZIP | sed 's/SLS_//' | tr A-Z a-z)
  unzip -L -q "$ZIP" -d "$TEMPDIR/packages/$DISK"
  rm "$ZIP"
done

EXTRACT_BOOT_IMAGE=$TEMPDIR/packages/a1/a1
EXTRACT_ROOT_IMAGE=$TEMPDIR/packages/a2/a2
EXTRACT_PACKAGES=$TEMPDIR/packages
extract_install_files
