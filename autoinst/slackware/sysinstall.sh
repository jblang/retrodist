# installer for SLS sysinstall-based versions
INSTSRC=$INSTMOUNT/install

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

echo "## performing $INSTTYPE install; please wait..."

mkdir -p $ROOTMOUNT/install/installed
mkdir -p $ROOTMOUNT/install/disks
mkdir -p $ROOTMOUNT/install/scripts
mkdir -p $ROOTMOUNT/install/catalog
sysinstall -instsrc $INSTSRC -instroot $ROOTMOUNT -$INSTTYPE
mv $ROOTMOUNT/fstab.tmp $ROOTMOUNT/etc/fstab

echo '## configuring system...'

# normal VGA mode
VGAMODE=-1

# Configure kernel with boot device and vga mode
echo "FLOPPYA $INSTDEV" >> $ROOTMOUNT/etc/hwconfig
echo "ROOTDEV $ROOTDEV" >> $ROOTMOUNT/etc/hwconfig
echo "VGAMODE $VGAMODE" >> $ROOTMOUNT/etc/hwconfig

# Skip modem/mouse config and install Linux-only LILO
cd $ROOTMOUNT
etc/syssetup -instroot $ROOTMOUNT -install <<EOF
n
n
2
EOF

# set up autoconf script to run on first boot
cp $INSTMOUNT/autoinst.d/autoconf.sh $ROOTMOUNT
chmod +x $ROOTMOUNT/autoconf.sh
echo "if [ -x /autoconf.sh ]; then" >> $ROOTMOUNT/etc/rc.local
echo "  /autoconf.sh" >> $ROOTMOUNT/etc/rc.local
echo "fi" >> $ROOTMOUNT/etc/rc.local