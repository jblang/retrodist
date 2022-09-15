mkdir -p $CACHEDIR/install
cp -lR $SLACKBASE/slackware-pre-1.0-beta $CACHEDIR/install/install
mkdir -p $CACHEDIR/install/install/a1
mv $CACHEDIR/install/install/diska01 $CACHEDIR/install/install/a1/a1disk
for DISK in "$CACHEDIR"/install/install/diska*; do
  NUM=$(basename "$DISK" | sed 's/diska0*//')
  if [[ -d "$DISK" ]]; then
    mv "$DISK" "$CACHEDIR/install/install/a$NUM"
  fi
done
cp $CACHEDIR/install/install/a1/a1disk $CACHEDIR/boot.img