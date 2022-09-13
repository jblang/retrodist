# Enable serial console on ttyS0
ETCPATH=$ROOTMOUNT/etc
if [ -d "$ETCPATH" ]; then
    echo '## Configuring serial console...'

    # add s0 entry in inittab
    if [ -x "$ROOTMOUNT/sbin/getty" ]; then
        GETTY="/sbin/getty"
    else
        GETTY="/etc/getty"
    fi
    cp $ETCPATH/inittab $ETCPATH/inittab.orig
    echo "s0:123456:respawn:$GETTY $TTYS $BAUD" >> $ETCPATH/inittab

    # Comment out CONSOLE line login.defs to use securetty instead
    if [ -f "$ETCPATH/login.defs" ]; then
        cp $ETCPATH/login.defs $ETCPATH/login.defs.orig
        sed 's/^CONSOLE/#CONSOLE/' $ETCPATH/login.defs.orig > $ETCPATH/login.defs
    fi

    # add ttyS0 to securetty
    cp $ETCPATH/securetty $ETCPATH/securetty.orig
    echo "$TTYS" >> $ETCPATH/securetty
fi