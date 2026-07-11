SLACK_D=$DOWNLOAD_D/slackware-1.1.2
EXTRACT_BOOT_IMAGE=$SLACK_D/bootdisk/1_44meg/bareboot.gz
EXTRACT_ROOT_IMAGE=$SLACK_D/bootdisk/1_44meg/color144.gz
EXTRACT_PACKAGES=$SLACK_D
extract_install_files
gunzip bareboot.gz color144.gz
extract_link_boot_media bareboot color144
