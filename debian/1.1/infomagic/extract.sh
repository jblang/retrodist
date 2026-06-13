EXTRACT_SOURCE=disc3.iso
DISKDIR=buzz-updates/disks-i386/1996_7_14
EXTRACT_BOOT_IMAGE=$DISKDIR/boot1440.bin
EXTRACT_ROOT_IMAGE=$DISKDIR/root.bin
EXTRACT_EXTRA_IMAGES=("$DISKDIR"/base14-*.bin)
EXTRACT_FAT_FILES=("$DISKDIR/base1_1.tgz")
extract_install_files
debian_extract_fat_image boot.img fat/bootflop LINUX INSTALL.SH RDEV.SH SYS_MAP.GZ MODULES.TGZ
