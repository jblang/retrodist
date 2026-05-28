# unzip files from source archive to correct directory
unzip -q $ORIGDIR/sls-1992.11.zip
mkdir -p install/install
for ZIP in SLS-1992.11/*.ZIP; do
  DISK=$(basename $ZIP .ZIP | sed 's/SLS_//' | tr A-Z a-z)
  unzip -L -q $ZIP -d install/install/$DISK
  rm $ZIP
done

cp install/install/a1/a1 boot.img
cp install/install/a2/a2 root.img