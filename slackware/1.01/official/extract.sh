SOURCE_D=$DOWNLOAD_D/slackware-1.01
EXTRACT_BOOT_IMAGE=$SOURCE_D/a1/a1disk
EXTRACT_PACKAGES=$SOURCE_D
extract_install_files
rm -rf fat/install
mv fat/packages fat/install
