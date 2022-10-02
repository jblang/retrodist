7z x $ORIGDIR/disc1.iso \
    distributions/debian/dist > /dev/null
mv distributions/debian/dist/base/* .
mkdir -p install/packages
mv distributions/debian/dist/packages/*/*.deb install/packages
rm -rf distributions
gunzip *.gz
mv bootdisk boot.img
mv basedsk1 install/basedsk1.img
mv basedsk2 install/basedsk2.img
autoinst_prep 500M