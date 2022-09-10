# Device information
SWAPDEVICE=/dev/hda1
SWAPSIZE=16384

ROOTDEVICE=/dev/hda2
ROOTMOUNT=/root

INSTDEV=/dev/fd0
INSTSRC=/mnt/install

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

# rdev video modes: -3=Ask, -2=Extended, -1=NormalVga, 1=key1, 2=key2...
VGAMODE=-1