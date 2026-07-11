unzip -q "$DOWNLOAD_D/slackware.zip" -d "$TEMP_D"

for IMG in "$TEMP_D"/[atx]*.img; do
  DISK=$(basename "$IMG" .img)
  if [[ "$DISK" != "a1" ]]; then
    mkdir -p "$TEMP_D/packages/$DISK"
    7z x -y -o"$TEMP_D/packages/$DISK" "$IMG" >/dev/null
  fi
done

EXTRACT_BOOT_IMAGE=$TEMP_D/a1.img
EXTRACT_PACKAGES=$TEMP_D/packages
extract_install_files
rm -rf fat/install
mv fat/packages fat/install
