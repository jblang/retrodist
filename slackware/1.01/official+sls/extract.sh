shopt -s nullglob
rm -rf fat/install
mkdir -p fat/install
IMAGES=(./[atx]*.img)
if [[ ${#IMAGES[@]} -eq 0 ]]; then
  echo "No Slackware disk images were staged" >&2
  exit 1
fi
for IMG in "${IMAGES[@]}"; do
  DISK=$(basename "$IMG" .img)
  if [[ "$DISK" != "a1" ]]; then
    mkdir -p "fat/install/$DISK"
    mcopy -s -i "$IMG" '::*' "fat/install/$DISK"
    rm "$IMG"
  fi
done

rm -f slack101.img boot.img start
ln -s a1.img boot.img
