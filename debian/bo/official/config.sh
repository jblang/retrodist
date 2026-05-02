# download configuration
DEBMIRROR_RELEASE="bo"

# extract configuration
custom_extract() {
  BOBASE="$DEBIANBASE/bo/main"
  DISKDIR="$BOBASE/disks-i386/current"

  cp -lR "$BOBASE/msdos-i386" install
  cp -l "$DISKDIR/base1_3.tgz" install/

  cp "$DISKDIR/resc1440.bin" boot.img
  cp "$DISKDIR/root.bin" root.img
  7z x -y -o. boot.img LINUX >/dev/null
  mv -f LINUX kernel
  mkdir -p install/drivers
  7z x -y -oinstall/drivers "$DISKDIR/drv1440.bin" >/dev/null
  for FILE in install/drivers/*; do
    LOWER=$(echo "$(basename "$FILE")" | tr '[:upper:]' '[:lower:]')
    if [[ "$(basename "$FILE")" != "$LOWER" ]]; then
      mv "$FILE" "install/drivers/$LOWER"
    fi
  done
  cp "$DISKDIR"/base14-*.bin .

  ln -sf ../base14-1.bin install/basedsk1.img
  ln -sf ../base14-2.bin install/basedsk2.img
  ln -sf ../base14-3.bin install/basedsk3.img
  ln -sf ../base14-4.bin install/basedsk4.img

  autoinst_prep 500M
}

# Installation devices
SWAPDEV=/dev/hda1
SWAPSIZE=65536

ROOTDEV=/dev/hda2
ROOTFS=ext2

# auto-install steps
AUTOINST_STEPS="common/diskinit.sh
debian/baseinst/bo.sh"

# serial configuration
TTYDEV=ttyS0
TTYBAUD=9600

# mouse configuration
MOUSEDEV=cua1
MOUSETYPE=Microsoft

# network configuration
HOSTNAME="debra"
DOMAINNAME="debian.org"
IPADDR="10.0.2.93"
NETMASK="255.255.255.0"
NETWORK="10.0.2.0"
BROADCAST="10.0.2.255"
GATEWAY="10.0.2.2"
NAMESERVER="10.0.2.1"
