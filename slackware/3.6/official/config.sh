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
# K   - Linux kernel source
# N   - Networking (TCP/IP, UUCP, Mail)
# T   - TeX
# TCL - Tcl/Tk/TclX, Tcl language, and Tk toolkit for developing X apps
# X   - XFree86 Base X Window System
# XAP - X Window Applications
# XD  - XFree86 X11 server development system
# XV  - XView (OpenLook [virtual] Window Manager, apps)
# Y   - Games (that do not require X)
SETS="a ap d e f k n t tcl x xap xd xv y"

# time zone
TIMEZONE="US/Central"

# serial configuration
TTYDEV=ttyS0
TTYBAUD=9600

# mouse configuration
MOUSEDEV=psaux
MOUSETYPE=PS/2

# network configuration
HOSTNAME="darkstar"
DOMAINNAME="frop.org"
IPADDR="10.0.2.36"
NETMASK="255.255.255.0"
NETWORK="10.0.2.0"
BROADCAST="10.0.2.255"
GATEWAY="10.0.2.2"
NAMESERVER="10.0.2.1"
