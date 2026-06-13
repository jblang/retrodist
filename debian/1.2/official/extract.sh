DISKDIR=$DEBIANBASE/rex/main/disks-i386/current
EXTRACT_BOOT_IMAGE=$DISKDIR/resq1440.bin
EXTRACT_ROOT_IMAGE=$DISKDIR/root.bin
EXTRACT_EXTRA_IMAGES=("$DISKDIR/drv1440.bin" "$DISKDIR"/base14-*.bin)
EXTRACT_FAT_FILES=("$DISKDIR/base1_2.tgz")
extract_install_files
debian_extract_fat_image boot.img fat/bootflop LINUX INSTALL.SH RDEV.SH SYS_MAP.GZ TYPE.TXT
debian_extract_fat_image drv1440.bin fat/drivers MODULES.TGZ INSTALL.SH TYPE.TXT
