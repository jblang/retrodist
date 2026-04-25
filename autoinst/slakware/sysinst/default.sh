# installer for SLS sysinstall-based versions
INSTSRC=$SOURCEMOUNT/install

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

mkdir -p $TARGETMOUNT/install/installed
mkdir -p $TARGETMOUNT/install/disks
mkdir -p $TARGETMOUNT/install/scripts
mkdir -p $TARGETMOUNT/install/catalog
sysinstall -instsrc $INSTSRC -instroot $TARGETMOUNT -$INSTTYPE
mv $TARGETMOUNT/fstab.tmp $TARGETMOUNT/etc/fstab

echo '## configuring system...'

# normal VGA mode
VGAMODE=-1

# Configure kernel with boot device and vga mode
echo "FLOPPYA $INSTDEV" >> $TARGETMOUNT/etc/hwconfig
echo "ROOTDEV $ROOTDEV" >> $TARGETMOUNT/etc/hwconfig
echo "VGAMODE $VGAMODE" >> $TARGETMOUNT/etc/hwconfig

# Skip modem/mouse config and install Linux-only LILO
cd $TARGETMOUNT
etc/syssetup -instroot $TARGETMOUNT -install <<EOF
n
n
2
EOF

# set up autoconf script to run on first boot
cp $SOURCEMOUNT/autoinst.d/autoconf.sh $TARGETMOUNT
chmod +x $TARGETMOUNT/autoconf.sh
echo "if [ -x /autoconf.sh ]; then" >> $TARGETMOUNT/etc/rc.local
echo "  /autoconf.sh" >> $TARGETMOUNT/etc/rc.local
echo "fi" >> $TARGETMOUNT/etc/rc.local
