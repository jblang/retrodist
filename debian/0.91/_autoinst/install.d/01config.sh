# Device information
SWAPDEVICE=/dev/hda1
SWAPSIZE=16384

ROOTDEVICE=/dev/hda2
ROOTMOUNT=/root
ROOTFSTYPE=ext2

INSTDEV=/dev/fd0
INSTSRC=/mnt/install

# Whether to configure VGA16 X11 Server (not supported by XFree86 1.x)
SKIPVGA16=1

# serial configuration
TTYS=ttyS0
BAUD=9600
 
# network configuration
HOSTNAME="debra"
DOMAINNAME="debian.org"
IPADDR="10.0.2.91"
NETMASK="255.255.255.0"
NETWORK="10.0.2.0"
BROADCAST="10.0.2.255"
GATEWAY="10.0.2.2"
NAMESERVER="10.0.2.1"
