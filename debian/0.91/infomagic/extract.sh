mount_copy $ORIGDIR/disc1.iso . \
    /distributions/debian/dist
mv dist/base/* .
mkdir -p install/packages
mv dist/packages/*/*.deb install/packages
rm -rf dist
gunzip *.gz
mv bootdisk boot.img
mv basedsk1 install/basedsk1.img
mv basedsk2 install/basedsk2.img
autoinst_prep 500M