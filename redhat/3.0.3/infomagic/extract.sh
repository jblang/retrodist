EXTRACT_SOURCE=disc2.iso
EXTRACT_BOOT_IMAGE=images/1213/boot0015.img
EXTRACT_EXTRA_IMAGES=(images/rescue.img images/ramdisk1.img images/ramdisk2.img)
extract_install_files
extract_truncate_floppy_image boot0015.img
