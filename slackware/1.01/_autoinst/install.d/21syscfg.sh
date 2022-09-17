echo '## configuring system...'

# Configure kernel with boot device and vga mode
echo "FLOPPYA $INSTDEV" >> /root/etc/hwconfig
echo "ROOTDEV $ROOTDEVICE" >> /root/etc/hwconfig
echo "VGAMODE $VGAMODE" >> /root/etc/hwconfig
rdev $INSTDEV $ROOTDEVICE
rdev -v $INSTDEV $VGAMODE
sync

# No modem, PS/2 mouse, and Linux-only LILO
cd $ROOTMOUNT
etc/syssetup -instroot $ROOTMOUNT -install <<EOF
n
y
2
2
EOF