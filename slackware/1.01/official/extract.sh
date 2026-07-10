SOURCE=$SLACKBASE/slackware-1.01
EXTRACT_BOOT_IMAGE=$SOURCE/a1/a1disk
EXTRACT_PACKAGES=$SOURCE
extract_install_files
rm -rf fat/install
mv fat/packages fat/install
