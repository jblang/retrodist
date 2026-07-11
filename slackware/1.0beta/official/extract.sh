cp -pR $DOWNLOAD_D/slackware-pre-1.0-beta "$TEMP_D/packages"
mkdir -p "$TEMP_D/packages/a1"
mv "$TEMP_D/packages/diska01" "$TEMP_D/packages/a1/a1disk"
for DISK in "$TEMP_D"/packages/diska*; do
  NUM=$(basename "$DISK" | sed 's/diska0*//')
  if [[ -d "$DISK" ]]; then
    mv "$DISK" "$TEMP_D/packages/a$NUM"
  fi
done
EXTRACT_BOOT_IMAGE=$TEMP_D/packages/a1/a1disk
EXTRACT_PACKAGES=$TEMP_D/packages
extract_install_files
rm -rf fat/install
mv fat/packages fat/install
