# download configuration
DOWNLOAD_LIST="slackware.tar.gz https://archive.org/download/slackware-beta/slack-pre1.0.tar.gz"

# extract configuration
custom_extract() {
  mkdir -p install
  tar xfz "$ORIGDIR/slackware.tar.gz"
  mv slack-pre1.0 install/install
  mkdir -p install/install/a1
  mv install/install/a1.img install/install/a1/a1disk
  cp install/install/a1/a1disk boot.img
  autoinst_prep 500M
}

# Installation devices
SWAPDEV=/dev/hda1
SWAPSIZE=16384

ROOTDEV=/dev/hda2
ROOTFS=ext2

# auto-install steps
AUTOINST_STEPS="common/diskinit.sh
slakware/sysinst/default.sh"

# serial configuration
TTYDEV=ttyS0
TTYBAUD=9600

# mouse configuration
MOUSEDEV=ps2aux
MOUSETYPE=PS/2
 

# network configuration
HOSTNAME="darkstar"
DOMAINNAME="frop.org"
IPADDR="10.0.2.100"
NETMASK="255.255.255.0"
NETWORK="10.0.2.0"
BROADCAST="10.0.2.255"
GATEWAY="10.0.2.2"
NAMESERVER="10.0.2.1"

# auto-config steps
AUTOCONF_STEPS="common/ttycfg.sh
common/netcfg.sh
common/mailcfg.sh
common/xconfig.sh"
