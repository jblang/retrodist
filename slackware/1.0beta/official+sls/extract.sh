EXTRACT_SOURCE=slackware.tar.gz
EXTRACT_BOOT_IMAGE=slack-pre1.0/a1.img
EXTRACT_PACKAGES=slack-pre1.0
extract_install_files
rm -rf fat/install
mv fat/packages fat/install
