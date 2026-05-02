# download configuration
CDROM_SOURCE="infomagic/ldr/1994_10"

# extract configuration
EXTRACT_MEDIA="disc1.iso"
EXTRACT_INSTALL_PATH="slakware"
EXTRACT_BOOT_PATH="slakinst/boot144/bare"
EXTRACT_ROOT_PATH="slakinst/root144/tty144"
AUTOINST_DISK_SIZE="500M"

# QEMU overrides
QEMU_RAM=64M

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
# I   - Info pages.
# IV  - Interviews: libraries, include files, Doc and Idraw apps for X
# N   - Networking (TCP/IP, UUCP, Mail)
# OOP - Object Oriented Programming (GNU Smalltalk 1.1.1)
# Q   - Extra kernels with special drivers (needed for UMSDOS/non-SCSI CD)
# T   - TeX
# TCL - Tcl/Tk/TclX, Tcl language, and Tk toolkit for developing X apps
# X   - XFree-86 2.1.1 Base X Window System
# XAP - X Applications
# XD  - XFree-86 2.1.1 X11 server development system
# XV  - XView 3.2 release 5. (OpenLook [virtual] Window Manager, apps)
# Y   - Games (that do not require X)
SETS="a ap d e f i iv n oop t tcl x xap xd xv y"

# package selection overrides
SKP_PACKAGES="scsikern
scsi
x_8514
x_mach32
x_mach8
x_mono
x_s3
x_vga16
x3118514
x311agx
x311ma8
x311ma32
x311ma64
x311mono
x311p9k
x311s3
x311vga
x311w32"

# auto-install steps
AUTOINST_STEPS="common/diskinit.sh
slakware/pkginst/112+.sh"

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
IPADDR="10.0.2.201"
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
