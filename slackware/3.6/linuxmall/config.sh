# download configuration
DOWNLOAD_LIST="slackware-3.6.7z https://archive.org/download/walnut-creek-slackware-36-intel-linux-mall/Walnut%20Creek%20Slackware%203.6%20%5BLinux%20Mall%5D.7z"

# extract configuration
custom_extract() {
  7z x -y -o"$EXTRACTDIR" "$ORIGDIR/slackware-3.6.7z" > /dev/null
  bchunk "$EXTRACTDIR/SLK3609118-1.bin" "$EXTRACTDIR/SLK3609118-1.cue" "$EXTRACTDIR/SLK3609118-1" > /dev/null
  rm "$EXTRACTDIR/SLK3609118-1.bin" "$EXTRACTDIR/SLK3609118-1.cue"
  mv "$EXTRACTDIR/SLK3609118-101.iso" "$ORIGDIR/disc1.iso"
}

# QEMU overrides
QEMU_MACHINE="type=pc"
QEMU_RAM=64M
QEMU_HD_SIZE=2G
QEMU_VGA="cirrus"
