DISK_D=$DOWNLOAD_D/buzz/main/disks-i386/1996_6_16
EXTRACT_BOOT_IMAGE=$DISK_D/boot1440.bin
EXTRACT_ROOT_IMAGE=$DISK_D/root.bin
EXTRACT_EXTRA_IMAGES=("$DISK_D"/base14-*.bin)
EXTRACT_FAT_FILES=("$DISK_D/base1_1.tgz")
extract_install_files
# The boot floppy is only staged for MODULES.TGZ, which supplies serial.o.
debian_extract_fat_image boot.img fat/bootflop MODULES.TGZ
debian_extract_fat_serial fat/bootflop/modules.tgz
