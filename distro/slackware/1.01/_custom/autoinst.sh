#!/bin/sh
# Automatic installation for Slackware 1.01
#
# copyright Softlanding Software 92,93.  Distribute freely, don't restrict
#
# Modified extensively for the Slackware Linux release 1.0 at 0.99pl11A.
# Any questions, bug reports, or suggestions for improvements in this
# release should be directed to Patrick Volkerding at the address
# volkerdi@mhd1.moorhead.msus.edu or bf703@cleveland.freenet.edu.
# Voice calls are accepted at (218) 233-4349. Support contracts available.
#
# Improvement suggestions are more than welcome!!!
#
# more mods for v. 1.00 7/12/93
# ...and still more for v. 1.01 8/2/93
#
# Updated by J.B. Langston 8/24/2022 to be fully automated

# creates 16MB of swap on partition 1
# creates an ext2 filesystem on partition 2
fdisk /dev/hda <<EOF
n
p
1
1
33
t
1
82
n
p
2
34
1015
t
2
83
w
EOF
mkswap /dev/hda1 16384
swapon /dev/hda1
mke2fs /dev/hda2

# The original script prompted for these values
ROOTDEVICE=/dev/hda2
INSTSRC=/mnt/install
INSTTYPE=X11
INSTDEV=/dev/fd0

# The meat of the original script with a lot of unnecessary stuff removed
mount -t ext2 $ROOTDEVICE /root
mkdir -p /root/install/installed
mkdir -p /root/install/disks
mkdir -p /root/install/scripts
mkdir -p /root/install/catalog
echo "$ROOTDEVICE	/		$MOUNTTYPE	defaults" > /root/fstab.tmp
sysinstall -instdev $INSTDEV -instsrc $INSTSRC -instroot /root -$INSTTYPE
mv /root/fstab.tmp /root/etc/fstab
echo "FLOPPYA $INSTDEV" >> /root/etc/hwconfig
echo "ROOTDEV $ROOTDEVICE" >> /root/etc/hwconfig
VGAMODE=-3
rdev $INSTDEV $ROOTDEVICE
rdev -v $INSTDEV -1
sync
echo "VGAMODE $VGAMODE" >> /root/etc/hwconfig

# Set up modem on first com port, PS/2 mouse, and Linux-only LILO
cd /root
etc/syssetup -instroot /root -install <<EOF
y
1
y
2
2
EOF
echo "Applying custom configuration..."
cp /mnt/xconfig /root/usr/lib/X11/Xconfig
cp /mnt/inittab /root/etc/inittab
cp /mnt/login.def /root/etc/login.defs
cp /mnt/rcinet1 /root/conf/net/rc.inet1
cp /mnt/hosts /root/conf/net/hosts
cp /mnt/host.cnf /root/conf/net/host.conf
cp /mnt/resolv.cnf /root/conf/net/resolv.conf
sync
reboot