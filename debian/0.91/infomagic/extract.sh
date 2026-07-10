DISTDIR=distributions/debian/dist
EXTRACT_SOURCE=disc1.iso
EXTRACT_EXTRA_IMAGES=(
    $DISTDIR/base/bootdisk.gz
    $DISTDIR/base/basedsk1.gz
    $DISTDIR/base/basedsk2.gz
)
EXTRACT_PACKAGES=$DISTDIR/packages
extract_install_files
gunzip *.gz
retro_link_boot_root bootdisk