# download configuration
DEBMIRROR_RELEASE="buzz"

# extract configuration
custom_extract() {
  BUZZBASE="$DEBIANBASE/buzz/main"
  DISKDIR="$BUZZBASE/disks-i386/1996_6_16"

  cp -lR "$BUZZBASE/msdos-i386" install
  cp -l "$DISKDIR/base1_1.tgz" install/

  cp "$DISKDIR/boot1440.bin" boot.img
  cp "$DISKDIR/root.bin" root.img
  cp "$DISKDIR"/base14-*.bin .

  ln -sf ../base14-1.bin install/basedsk1.img
  ln -sf ../base14-2.bin install/basedsk2.img
  ln -sf ../base14-3.bin install/basedsk3.img

  autoinst_prep 500M
}

# Installation devices
SWAPDEV=/dev/hda1
SWAPSIZE=65536

ROOTDEV=/dev/hda2
ROOTFS=ext2

# auto-install steps
AUTOINST_STEPS="common/diskinit.sh
debian/baseinst/buzz.sh"

# serial configuration
TTYDEV=ttyS0
TTYBAUD=9600

# mouse configuration
MOUSEDEV=cua1
MOUSETYPE=Microsoft

# network configuration
HOSTNAME="debra"
DOMAINNAME="debian.org"
IPADDR="10.0.2.91"
NETMASK="255.255.255.0"
NETWORK="10.0.2.0"
BROADCAST="10.0.2.255"
GATEWAY="10.0.2.2"
NAMESERVER="10.0.2.1"
