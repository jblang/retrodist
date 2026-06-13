EXTRACT_SOURCE=disc1.iso
EXTRACT_BOOT_IMAGE=sunsite/distributions/slackware/bootdisk/1_44meg/uniboot
EXTRACT_PACKAGES=sunsite/distributions/slackware
extract_install_files

# 1.1.1 x_svga.tgz has CRC error, so borrow working package from 1.1.2
cp "$ORIGDIR/x_svga.tgz" fat/packages/x2/x_svga.tgz
