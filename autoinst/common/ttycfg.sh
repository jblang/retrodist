# Enable serial console on ttyS0
echo "### Enabling serial console on $TTYDEV..."

ETCPATH=/etc
if [ -f "$ETCPATH/inittab" ]; then
    # find location of getty
    if [ -x "/sbin/getty" ]; then
        GETTY="/sbin/getty"
    else
        GETTY="/etc/getty"
    fi

    # add serial console in inittab
    cp $ETCPATH/inittab $ETCPATH/inittab.orig
    echo "s0:123456:respawn:$GETTY $TTYDEV $TTYBAUD" >> $ETCPATH/inittab

    # Comment out CONSOLE line login.defs to use /etc/securetty instead
    # needed for Slackware 1.01
    if [ -f "$ETCPATH/login.defs" ]; then
        cp $ETCPATH/login.defs $ETCPATH/login.defs.orig
        sed 's/^CONSOLE/#CONSOLE/' $ETCPATH/login.defs.orig > $ETCPATH/login.defs
    fi

    # add ttyS0 to securetty
    cp $ETCPATH/securetty $ETCPATH/securetty.orig
    echo "$TTYDEV" >> $ETCPATH/securetty
fi