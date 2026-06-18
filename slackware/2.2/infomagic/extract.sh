EXTRACT_SOURCE=disc1.iso
EXTRACT_BOOT_IMAGE=slakinst/boot144/bare
EXTRACT_ROOT_IMAGE=slakinst/root144/color144
# 2.2 claims support for IDE CD-ROM drives, but the idecd boot disk
# doesn't seem to have support for iso9660 filesystems compiled in.
# the workaround is to extract the packages to the fat partition.
EXTRACT_PACKAGES=slakware
extract_install_files
