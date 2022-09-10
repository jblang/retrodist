# Enable serial console on ttyS0
ETCPATH=$ROOTMOUNT/etc
if [ -d "$ETCPATH" ]; then
    echo '### Configuring serial console...'

    # add s0 entry in inittab
    cp $ETCPATH/inittab $ETCPATH/inittab.orig
    echo "s0:6:respawn:/etc/getty 9600 ttyS0" >> $ETCPATH/inittab

    # change login.defs to get allowed root consoles from securetty
    cp $ETCPATH/login.defs $ETCPATH/login.defs.orig
    sed 's/^CONSOLE/#CONSOLE/' $ETCPATH/login.defs.orig > $ETCPATH/login.defs
    echo "CONSOLE /etc/securetty" >> $ETCPATH/login.defs

    # add ttyS0 to securetty
    cp $ETCPATH/securetty $ETCPATH/securetty.orig
    echo "ttyS0" >> $ETCPATH/securetty
fi