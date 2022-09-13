# Device information
SWAPDEVICE=/dev/hda1
SWAPSIZE=16384

ROOTDEVICE=/dev/hda2
ROOTMOUNT=/root
ROOTFSTYPE=ext2

INSTDEV=/dev/fd0
INSTSRC=/mnt/install

# mini - Install the base Slackware Linux disks (series A)
# X11 - Install the Slackware series A + Slackware or SLS series X (X11)
# tex - Install the Slackware series A + X (X Windows) + T (TeX support)
# everything - Install everything (90 Meg)
if [ -d "$INSTSRC/x1" ]; then
    if [ -d "$INSTSRC/t1" ]; then
        INSTTYPE=tex
    else
        INSTTYPE=X11
    fi
else
    INSTTYPE=mini
fi

# rdev video modes: -3=Ask, -2=Extended, -1=NormalVga, 1=key1, 2=key2...
VGAMODE=-1
 
# Whether to configure VGA16 X11 Server (not supported by XFree86 1.x)
SKIPVGA16=1

# serial configuration
TTYS=ttyS0
BAUD=9600
 
# network configuration
HOSTNAME="darkstar"
DOMAINNAME="frop.org"
IPADDR="10.0.2.10"
NETMASK="255.255.255.0"
NETWORK="10.0.2.0"
BROADCAST="10.0.2.255"
GATEWAY="10.0.2.2"
NAMESERVER="10.0.2.1"