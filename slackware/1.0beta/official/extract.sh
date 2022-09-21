mkdir -p install
cp -lR $SLACKBASE/slackware-pre-1.0-beta install/install
mkdir -p install/install/a1
mv install/install/diska01 install/install/a1/a1disk
for DISK in install/install/diska*; do
  NUM=$(basename "$DISK" | sed 's/diska0*//')
  if [[ -d "$DISK" ]]; then
    mv "$DISK" "install/install/a$NUM"
  fi
done
cp install/install/a1/a1disk boot.img
autoinst_prep 500M