# Arrange the ZIP files already extracted into qemu.d by the declarative source.
shopt -s nullglob
rm -rf fat/install
mkdir -p fat/install
ZIPS=(./*.ZIP)
if [[ ${#ZIPS[@]} -eq 0 ]]; then
  echo "No Slackware ZIP sets were staged" >&2
  exit 1
fi
for ZIP in "${ZIPS[@]}"; do
  DISK=$(basename "$ZIP" .ZIP | sed 's/SK101//' | tr '[:upper:]' '[:lower:]')
  unzip -L -q "$ZIP" -d "fat/install/$DISK"
  rm "$ZIP"
done

# Use IDE packages for the a2 set (a2s is SCSI)
mv fat/install/a2i fat/install/a2

# clean up some files that got put into the wrong dirs
for WRONGLABEL in fat/install/a*/diskx* fat/install/x*/diska*; do
  WRONG_D=$(dirname "$WRONGLABEL")
  FILES=$(cut -d: -f1 "$WRONGLABEL" | sort -u)
  for FILE in $FILES; do
    rm "$WRONG_D/$FILE.tgz"
  done
  rm "$WRONGLABEL"
done

unzip -L -q fat/install/a1/a1disk.zip
rm -f boot.img
ln -s a1disk boot.img
