# configure X11 for Cirrus card emulated by QEMU
X11PATH=$ROOTMOUNT/usr/lib/X11
if [ -d $X11PATH ]; then
    echo '### configuring X11...'
    cp $X11PATH/Xconfig $X11PATH/Xconfig.orig
    cp /mnt/autoinst.cf/xconfig $X11PATH/Xconfig
fi
# Pre 1.0 beta has an old version of X11
# and only the X386mono server works.
XMONO="$ROOTMOUNT/usr/X386/bin/X386mono"
if [ -f "$XMONO" ]; then
    (cd $(dirname $XMONO); ln -sf X386mono X)
fi