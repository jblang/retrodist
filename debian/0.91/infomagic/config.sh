# download configuration
CDROM_SOURCE="infomagic/ldr/1994_06"

# extract configuration
custom_extract() {
  7z x "$ORIGDIR/disc1.iso" distributions/debian/dist > /dev/null
  mv distributions/debian/dist/base/* .
  mkdir -p install/packages
  mv distributions/debian/dist/packages/*/*.deb install/packages
  rm -rf distributions
  gunzip *.gz
  mv bootdisk boot.img
  mv basedsk1 install/basedsk1.img
  mv basedsk2 install/basedsk2.img
  autoinst_prep 500M
}

# QEMU overrides
QEMU_RAM=64M
QEMU_EXTRA="-serial msmouse"

# Installation devices
SWAPDEV=/dev/hda1
SWAPSIZE=65536

ROOTDEV=/dev/hda2
ROOTFS=ext2

# auto-install steps
AUTOINST_STEPS="common/diskinit.sh
debian/baseinst/091.sh"

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

# auto-config steps
AUTOCONF_STEPS="debian/dpkginst/default.sh
common/ttycfg.sh
common/netcfg.sh
common/xconfig.sh"
