DISK_D=$DOWNLOAD_D/rex/main/disks-i386/current
EXTRACT_BOOT_IMAGE=$DISK_D/resq1440.bin
EXTRACT_ROOT_IMAGE=$DISK_D/root.bin
EXTRACT_EXTRA_IMAGES=("$DISK_D/drv1440.bin" "$DISK_D"/base14-*.bin)
EXTRACT_FAT_FILES=("$DISK_D/base1_2.tgz")
extract_install_files
# The driver floppy is only staged for MODULES.TGZ, which supplies serial.o.
debian_extract_fat_image drv1440.bin fat/drivers MODULES.TGZ
debian_extract_fat_serial fat/drivers/modules.tgz
