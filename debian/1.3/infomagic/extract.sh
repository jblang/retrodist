DISK_D=bo/disks-i386/1997-05-30
EXTRACT_SOURCE=disc3.iso
EXTRACT_BOOT_IMAGE=$DISK_D/resc1440.bin
EXTRACT_ROOT_IMAGE=$DISK_D/root.bin
EXTRACT_EXTRA_IMAGES=("$DISK_D/drv1440.bin" "$DISK_D"/base-*.bin)
# dinstall's mounted-medium install needs the floppy images next to the
# base tarball on the FAT partition.
EXTRACT_FAT_FILES=("$DISK_D/base1_3.tgz" "$DISK_D/resc1440.bin" "$DISK_D/drv1440.bin")
extract_install_files
# The driver floppy is only staged for MODULES.TGZ, which supplies serial.o.
debian_extract_fat_image drv1440.bin fat/drivers MODULES.TGZ
debian_extract_fat_serial fat/drivers/modules.tgz
