EXTRACT_SOURCE=disc3.iso
DISKDIR=rex-updates/disks-i386/1997-01-18
EXTRACT_BOOT_IMAGE=$DISKDIR/rsc1440.bin
EXTRACT_ROOT_IMAGE=$DISKDIR/root.bin
EXTRACT_EXTRA_IMAGES=("$DISKDIR/drv1440.bin" "$DISKDIR"/base14-*.bin)
EXTRACT_FAT_FILES=("$DISKDIR/base1_2.tgz")
extract_install_files
debian_extract_fat_image boot.img fat/bootflop LINUX INSTALL.SH RDEV.SH SYS_MAP.GZ TYPE.TXT
debian_extract_fat_image drv1440.bin fat/drivers MODULES.TGZ INSTALL.SH TYPE.TXT
