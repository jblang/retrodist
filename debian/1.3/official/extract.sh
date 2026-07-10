DISKDIR=$DEBIANBASE/bo/main/disks-i386/current
EXTRACT_BOOT_IMAGE=$DISKDIR/resc1440.bin
EXTRACT_ROOT_IMAGE=$DISKDIR/root.bin
EXTRACT_EXTRA_IMAGES=("$DISKDIR/drv1440.bin" "$DISKDIR"/base-*.bin)
# dinstall's mounted-medium install needs the floppy images next to the
# base tarball on the FAT partition.
EXTRACT_FAT_FILES=("$DISKDIR/base1_3.tgz" "$DISKDIR/resc1440.bin" "$DISKDIR/drv1440.bin")
extract_install_files
# The driver floppy is only staged for MODULES.TGZ, which supplies serial.o.
debian_extract_fat_image drv1440.bin fat/drivers MODULES.TGZ
debian_extract_fat_serial fat/drivers/modules.tgz
