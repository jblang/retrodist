extract_sls_10_disk() {
  DISKFILE=$1
  DISKNAME=$2
  TMPDIR=$3

  mkdir -p "$TMPDIR/$DISKNAME"
  7z x -y "-o$TMPDIR/$DISKNAME" "$DISKFILE" >/dev/null
  rm -f "$DISKFILE"
  mv "$TMPDIR/$DISKNAME" "$DISKFILE"
}

tar xf $ORIGDIR/sls-1.0.tar.bz2
mv sls-0.99pl install
cp install/install/a1 boot.img
cp install/install/a2 root.img

TMPDIR=sls10-fat
mkdir "$TMPDIR"
for DISKFILE in install/install/[abcdstx][0-9]; do
  DISKNAME=$(basename "$DISKFILE")
  case "$DISKNAME" in
    a1 | a2) continue ;;
  esac
  extract_sls_10_disk "$DISKFILE" "$DISKNAME" "$TMPDIR"
done
rm -rf "$TMPDIR"
