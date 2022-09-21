# Automatic installation configuration file

# Installation devices
SWAPDEV=/dev/hda1
SWAPSIZE=16384

ROOTDEV=/dev/hda2
ROOTFS=ext2

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