# Enable serial console on ttyS0
echo "### Enabling serial console on $TTYDEV..."

ETCPATH=/etc
if [ -f "$ETCPATH/inittab" ]; then
    TTYID=${TTYID:-s0}
    TTYRUNLEVELS=${TTYRUNLEVELS:-123456}
    STOCKLINE=

    # Prefer the distro's stock serial stanza when one exists.
    if [ -z "$STOCKLINE" ]; then
        STOCKLINE=`sed -n "/^#s[0-9]:[0-9][0-9]*:respawn:.* $TTYDEV\\([ 	].*\\)\{0,1\}\$/p" $ETCPATH/inittab | sed -n '1p'`
    fi
    if [ -z "$STOCKLINE" ]; then
        STOCKLINE=`sed -n '/^#s[0-9]:[0-9][0-9]*:respawn:.* ttyS0\([ 	].*\)\{0,1\}$/p' $ETCPATH/inittab | sed -n '1p'`
    fi

    # allow per-release overrides for the serial getty implementation
    if [ -n "$STOCKLINE" ]; then
        GETTYLINE=`echo "$STOCKLINE" | \
            sed 's/^#//' | \
            sed "s/agetty [0-9][0-9]*/agetty $TTYBAUD/" | \
            sed "s/ttyS0/$TTYDEV/"`
    elif [ "$TTYGETTY_STYLE" = "agetty" ]; then
        if [ -x "/sbin/agetty" ]; then
            GETTYLINE="/sbin/agetty $TTYBAUD $TTYDEV ${TTYTERM:-vt100}"
        else
            echo "Warning: requested agetty for $TTYDEV but /sbin/agetty is missing"
            GETTYLINE=""
        fi
    else
        # find location of getty_ps-compatible getty
        if [ -x "/sbin/getty" ]; then
            GETTY="/sbin/getty"
        else
            GETTY="/etc/getty"
        fi
        GETTYLINE="$GETTY $TTYDEV $TTYBAUD"
    fi

    # add serial console in inittab
    cp $ETCPATH/inittab $ETCPATH/inittab.orig
    if [ -n "$GETTYLINE" ]; then
        HAVEGETTY=`sed -n "/^[^#].*respawn:.* $TTYDEV\\([ 	].*\\)\{0,1\}\$/p" $ETCPATH/inittab | sed -n '1p'`
        if [ -z "$HAVEGETTY" ]; then
            if [ -n "$STOCKLINE" ]; then
                sed "s|^$STOCKLINE\$|$GETTYLINE|" $ETCPATH/inittab.orig > $ETCPATH/inittab
            else
                cp $ETCPATH/inittab.orig $ETCPATH/inittab
                echo "$TTYID:$TTYRUNLEVELS:respawn:$GETTYLINE" >> $ETCPATH/inittab
            fi
        fi
    fi

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
