EXTRACT_SOURCE=disc4.iso
EXTRACT_BOOT_IMAGE=images/1211/boot0015.img
EXTRACT_EXTRA_IMAGES=(images/rescue.img images/rootdisk.img)
extract_install_files
extract_truncate_floppy_image boot0015.img
