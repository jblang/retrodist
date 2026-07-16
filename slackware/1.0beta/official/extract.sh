rm -rf fat/install
rm -f diska01 boot.img
mkdir -p fat/install
cp -pR "$DOWNLOAD_D/slackware-pre-1.0-beta/." fat/install/
mv fat/install/diska01 .
for DISK in fat/install/diska*; do
  NUM=$(basename "$DISK" | sed 's/diska0*//')
  if [[ -d "$DISK" ]]; then
    mv "$DISK" "fat/install/a$NUM"
  fi
done
ln -s diska01 boot.img
