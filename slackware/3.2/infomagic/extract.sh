EXTRACT_SOURCE=disc2.iso
EXTRACT_BOOT_IMAGE=bootdsks.144/bare.i
EXTRACT_ROOT_IMAGE=rootdsks/color.gz
extract_install_files
truncate -s1440k bare.i
