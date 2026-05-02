# download configuration
DOWNLOAD_LIST="slackware.zip https://archive.org/compress/slackware-101/formats=ZIP&file=/slackware-101.zip"

# extract configuration
custom_extract() {
  7z x "$ORIGDIR/slackware.zip" > /dev/null
  mkdir -p install/install
  for ZIP in *.ZIP; do
    DISK=$(basename "$ZIP" .ZIP | sed 's/SK101//' | tr A-Z a-z)
    7z x "$ZIP" -o"install/install/$DISK" > /dev/null
    lowercase_tree "install/install/$DISK"
    rm "$ZIP"
  done

  for ZIP in install/install/a1/*.zip; do
    7z x "$ZIP" -oinstall/install/a1 > /dev/null
    lowercase_tree install/install/a1
    rm "$ZIP"
  done
  mv install/install/a2i install/install/a2
  cp install/install/a1/a1disk boot.img

  WRONGDISKS=$(ls install/install/a*/diskx* install/install/x*/diska*)
  for WRONG in $WRONGDISKS; do
    WRONGDIR=$(dirname "$WRONG")
    NEWDIR=install/install/$(basename "$WRONG" | sed 's/disk//')b
    mkdir -p "$NEWDIR"
    FILES=$(cat "$WRONG" | cut -d: -f1 | sort | uniq)
    for FILE in $FILES; do
      mv "$WRONGDIR/$FILE.tgz" "$NEWDIR"
    done
    mv "$WRONG" "$NEWDIR"
  done

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
IPADDR="10.0.2.101"
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
