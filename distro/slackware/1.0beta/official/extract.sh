SOURCE=$SLACKBASE/slackware-pre-1.0-beta
cp -lR $SOURCE $CACHE/install
mkdir -p $CACHE/install/a1
mv $CACHE/install/diska01 $CACHE/install/a1/a1disk
for DISK in "$CACHE"/install/diska*; do
  NUM=$(basename "$DISK" | sed 's/diska0*//')
  if [[ -d "$DISK" ]]; then
    mv "$DISK" "$CACHE/install/a$NUM"
  fi
done
cp $CACHE/install/a1/a1disk $CACHE/boot.img