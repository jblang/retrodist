# Automatic installation configuration file

# Installation devices
SWAPDEV=/dev/hda1
SWAPSIZE=16384

ROOTDEV=/dev/hda2
ROOTFS=ext2

# A   - Base Linux system
# AP  - Various applications that do not need X
# D   - Program Development (C, C++, Kernel source, Lisp, Perl, etc.)
# E   - GNU Emacs
# F   - FAQ lists
# I   - Info pages
# N   - Networking (TCP/IP, UUCP, Mail)
# OOP - Object Oriented Programming
# Q   - Extra kernels
# T   - TeX
# TCL - Tcl/Tk/TclX
# X   - XFree86 base system
# XAP - X applications
# XD  - X development
# XV  - XView
# Y   - Games
SETS="a ap d e f i n oop q t tcl x xap xd xv y"

# time zone
TIMEZONE="US/Central"

# serial configuration
TTYDEV=ttyS0
TTYBAUD=9600

# mouse configuration
MOUSEDEV=ps2aux
MOUSETYPE=PS/2

# network configuration
HOSTNAME="darkstar"
DOMAINNAME="frop.org"
IPADDR="10.0.2.122"
NETMASK="255.255.255.0"
NETWORK="10.0.2.0"
BROADCAST="10.0.2.255"
GATEWAY="10.0.2.2"
NAMESERVER="10.0.2.1"
