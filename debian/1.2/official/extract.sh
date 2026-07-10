DISKDIR=$DEBIANBASE/rex/main/disks-i386/current
EXTRACT_BOOT_IMAGE=$DISKDIR/resq1440.bin
EXTRACT_ROOT_IMAGE=$DISKDIR/root.bin
EXTRACT_EXTRA_IMAGES=("$DISKDIR/drv1440.bin" "$DISKDIR"/base14-*.bin)
EXTRACT_FAT_FILES=("$DISKDIR/base1_2.tgz")
extract_install_files
# The driver floppy is only staged for MODULES.TGZ, which supplies serial.o.
debian_extract_fat_image drv1440.bin fat/drivers MODULES.TGZ
debian_extract_fat_serial fat/drivers/modules.tgz
