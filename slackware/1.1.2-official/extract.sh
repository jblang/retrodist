SLACKDIR=$SLACKBASE/slackware-1.1.2
EXTRACT_BOOT_IMAGE=$SLACKDIR/bootdisk/1_44meg/bareboot.gz
EXTRACT_ROOT_IMAGE=$SLACKDIR/bootdisk/1_44meg/tty144.gz
EXTRACT_PACKAGES=$SLACKDIR
extract_install_files
gunzip bareboot.gz tty144.gz
retro_link_boot_root bareboot tty144
