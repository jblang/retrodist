SLACKDIR=$SLACKBASE/slackware-3.6
EXTRACT_BOOT_IMAGE=$SLACKDIR/bootdsks.144/bare.i
EXTRACT_ROOT_IMAGE=$SLACKDIR/rootdsks/color.gz
EXTRACT_PACKAGES=$SLACKDIR/slakware
extract_install_files
extract_truncate_floppy_image bare.i
