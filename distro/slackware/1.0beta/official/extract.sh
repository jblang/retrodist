SOURCE=$SLACKBASE/slackware-pre-1.0-beta
mkdir -p $CACHE/install
cp $SOURCE/diska01 $CACHE/a1.img
for DISK in "$SOURCE"/diska*; do
  NUM=$(basename "$DISK" | sed 's/diska0*//')
  if [[ -d "$DISK" ]]; then
    cp -R "$DISK" "$CACHE/install/a$NUM"
  fi
done
