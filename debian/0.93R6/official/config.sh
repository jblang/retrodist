# download configuration
DEBMIRROR_RELEASE="Debian-0.93R6"

# extract configuration
custom_extract() {
  RELBASE="$DEBIANBASE/Debian-0.93R6"
  DISKDIR="$RELBASE/disks"

  cp -lR "$RELBASE/ms-dos" install
  gzip -dc "$DISKDIR/1440_boot_floppy.gz" > boot.img
  gzip -dc "$DISKDIR/1440_root_floppy.gz" > root.img
  cp "$DISKDIR"/1440_base_floppy-* .

  ln -sf ../1440_base_floppy-1 install/basedsk1.img
  ln -sf ../1440_base_floppy-2 install/basedsk2.img
  ln -sf ../1440_base_floppy-3 install/basedsk3.img

  autoinst_prep 500M
}

# Installation devices
SWAPDEV=/dev/hda1
SWAPSIZE=65536

ROOTDEV=/dev/hda2
ROOTFS=ext2

# auto-install steps
AUTOINST_STEPS="common/diskinit.sh
debian/baseinst/093r6.sh
debian/dpkginst/tree.sh"

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
