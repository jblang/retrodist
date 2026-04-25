echo '### Configuring networking...'

ETCPATH=/etc
RCPATH=$ETCPATH/rc.d
if [ -z "$NETDEV" ]; then
    NETDEV=eth0
fi

# standard network configuration
if [ -f "$RCPATH/rc.inet1" ]; then
    # hostname
    ORIG_HOSTNAME=$(cat $ETCPATH/HOSTNAME)
    cp $ETCPATH/HOSTNAME $ETCPATH/HOSTNAME.orig
    if [ -z "$DOMAINNAME" ]; then
        echo "$HOSTNAME" > $ETCPATH/HOSTNAME
    else
        echo "$HOSTNAME.$DOMAINNAME" > $ETCPATH/HOSTNAME
    fi

    # figure out where ifconfig and route commands are
    if [ -x "/sbin/ifconfig" ]; then
        IFCONFIG="/sbin/ifconfig"
        ROUTE="/sbin/route"
    elif [ -x "/etc/ifconfig" ]; then
        IFCONFIG="/etc/ifconfig"
        ROUTE="/etc/route"
    fi

    # if commands found, configure networking
    if [ -x "$IFCONFIG" ] && [ -x "$ROUTE" ]; then
        HAVE_NETDEV=
        if [ -r "/proc/net/dev" ]; then
            fgrep "$NETDEV:" /proc/net/dev >/dev/null 2>&1
            if [ $? = 0 ]; then
                HAVE_NETDEV=yes
            fi
        fi
        if [ -z "$HAVE_NETDEV" ]; then
            $IFCONFIG -a 2>/dev/null | fgrep "$NETDEV" >/dev/null 2>&1
            if [ $? = 0 ]; then
                HAVE_NETDEV=yes
            fi
        fi

        # rc.inet1
        cp $RCPATH/rc.inet1 $RCPATH/rc.inet1.orig
        echo "#!/bin/sh" > $RCPATH/rc.inet1
        if [ "$ORIG_HOSTNAME" = "debra.debian.org" ]; then
            echo "hostname -S" >> $RCPATH/rc.inet1
        else
            echo "HOSTNAME=$HOSTNAME" >> $RCPATH/rc.inet1
        fi
        echo "$IFCONFIG lo 127.0.0.1" >> $RCPATH/rc.inet1
        echo "$ROUTE add 127.0.0.1" >> $RCPATH/rc.inet1
        if [ -n "$HAVE_NETDEV" ]; then
            echo "$IFCONFIG $NETDEV $IPADDR broadcast $BROADCAST netmask $NETMASK" >> $RCPATH/rc.inet1
            # for reasons I don't understand debian and slackware 
            # require these routes to be set up slightly differently
            if [ "$ORIG_HOSTNAME" = "debra.debian.org" ]; then
                # debian
                echo "$ROUTE add $IPADDR" >> $RCPATH/rc.inet1
                echo "$ROUTE add $NETWORK" >> $RCPATH/rc.inet1
            else
                # slackware
                echo "$ROUTE -n add $NETWORK" >> $RCPATH/rc.inet1
            fi
            echo "$ROUTE add default gw $GATEWAY metric 1" >> $RCPATH/rc.inet1
        fi

        # hosts
        cp $ETCPATH/hosts $ETCPATH/hosts.orig
        echo "127.0.0.1   localhost" > $ETCPATH/hosts
        if [ -n "$HAVE_NETDEV" ]; then
            echo "$IPADDR     $HOSTNAME.$DOMAINNAME $HOSTNAME" >> $ETCPATH/hosts
        fi

        # resolv.conf
        cp $ETCPATH/resolv.conf $ETCPATH/resolv.conf.orig
        if [ -n "$HAVE_NETDEV" ]; then
            echo "domain $DOMAINNAME" > $ETCPATH/resolv.conf
            if [ -n "$NAMESERVER" ]; then
                echo "nameserver $NAMESERVER" >> $ETCPATH/resolv.conf
            fi
        else
            : > $ETCPATH/resolv.conf
        fi

        # networks
        if [ "$ORIG_HOSTNAME" = "debra.debian.org" -a -n "$HAVE_NETDEV" ]; then
            # again, for reasons I don't understand debian requires
            # localnet but slackware refuses to work if it is there
            cp $ETCPATH/networks $ETCPATH/networks.orig
            echo "localnet $NETWORK" > $ETCPATH/networks
        fi
    fi
elif [ -f "$ETCPATH/rc.net" ]; then
    # SLS's non-standard network configuration via /etc/hosts only
    echo '## Configuring networking via hosts...'

    cp $ETCPATH/hosts $ETCPATH/hosts.orig
	# Note: tab must separate IP and hostnames below, not spaces
    sed "s/.*$HOSTNAME$/$IPADDR	$HOSTNAME/" $ETCPATH/hosts > $ETCPATH/hosts.1
    sed "s/.*network$/$NETWORK	network/" $ETCPATH/hosts.1 > $ETCPATH/hosts
    sed "s/.*router$/$GATEWAY	router/" $ETCPATH/hosts > $ETCPATH/hosts.1
    mv $ETCPATH/hosts.1 $ETCPATH/hosts
fi
