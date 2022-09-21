# Automatic installation configuration file

# Installation devices
SWAPDEV=/dev/hda1
SWAPSIZE=65536

ROOTDEV=/dev/hda2
ROOTFS=ext2

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