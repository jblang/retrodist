DIST_D=distributions/debian/dist
EXTRACT_SOURCE=disc1.iso
EXTRACT_EXTRA_IMAGES=(
    $DIST_D/base/bootdisk.gz
    $DIST_D/base/basedsk1.gz
    $DIST_D/base/basedsk2.gz
)
EXTRACT_PACKAGES=$DIST_D/packages
extract_install_files
gunzip *.gz
extract_link_boot_media bootdisk
