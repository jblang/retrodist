SOURCE=$SLACKBASE/slackware-pre-1.0-beta
mkdir -p $CACHE/install/a1
mv $SOURCE/diska01 $CACHE/install/a1/a1disk
cp $CACHE/install/a1/a1disk $CACHE/boot.img
for DISK in "$SOURCE"/diska*; do
  NUM=$(basename "$DISK" | sed 's/diska0*//')
  if [[ -d "$DISK" ]]; then
    cp -R "$DISK" "$CACHE/install/a$NUM"
  fi
done
