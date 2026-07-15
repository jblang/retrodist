unzip -q "$DOWNLOAD_D/slackware.zip" -d "$TEMP_D"
mkdir -p "$TEMP_D/staged/packages"

for IMG in "$TEMP_D"/[atx]*.img; do
  DISK=$(basename "$IMG" .img)
  if [[ "$DISK" != "a1" ]]; then
    mkdir -p "$TEMP_D/staged/packages/$DISK"
    7z x -y -o"$TEMP_D/staged/packages/$DISK" "$IMG" >/dev/null
  fi
done

mv "$TEMP_D/a1.img" "$TEMP_D/staged/boot.img"
