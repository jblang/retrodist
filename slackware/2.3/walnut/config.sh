# download configuration
CDROM_SOURCE="walnut/slackware/2.3"

# extract configuration
EXTRACT_MEDIA="disc1.iso"
EXTRACT_INSTALL_PATH="slakware"
EXTRACT_BOOT_PATH="bootdsks.144/idecd"
EXTRACT_ROOT_PATH="rootdsks.144/tty144"
AUTOINST_DISK_SIZE="2G"

# QEMU overrides
QEMU_RAM=64M
QEMU_HD_SIZE=2G

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
# IV  - InterViews development, docs, and apps for X
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
SETS="a ap d e f i iv n oop t tcl x xap xd xv y"

# package selection overrides
SKP_PACKAGES="scsi"

# auto-install steps
AUTOINST_STEPS="common/diskinit.sh
slakware/pkginst/112+.sh"

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
IPADDR="10.0.2.23"
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
