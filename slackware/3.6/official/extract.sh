SLACK_D=$DOWNLOAD_D/slackware-3.6
EXTRACT_BOOT_IMAGE=$SLACK_D/bootdsks.144/bare.i
EXTRACT_ROOT_IMAGE=$SLACK_D/rootdsks/color.gz
EXTRACT_PACKAGES=$SLACK_D/slakware
extract_install_files
extract_truncate_floppy_image bare.i
