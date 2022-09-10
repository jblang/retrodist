# Enable networking on eth0
NETPATH=$ROOTMOUNT/conf/net
ETCPATH=$ROOTMOUNT/etc
if [ -f "$NETPATH/rc.inet1" ]; then
    echo '### Configuring networking...'

    # bring up eth0 in rc.inet1
    cp $NETPATH/rc.inet1 $NETPATH/rc.inet1.orig
    cat >> $NETPATH/rc.inet1 <<EOF
# qemu user network config
/etc/ifconfig eth0 10.0.2.101 netmask 255.255.255.0 broadcast 10.0.2.255 up
/etc/route add 10.0.2.0 eth0
/etc/route add default gw 10.0.2.2
EOF

    # add darkstar hostname to hosts
    cp $NETPATH/hosts $NETPATH/hosts.orig
    cat >> $NETPATH/hosts <<EOF
10.0.2.101 darkstar.frop.org darkstar
EOF    
    
    # replace host.conf
    cp $NETPATH/host.conf $NETPATH/host.conf.orig
    cat > $NETPATH/host.conf <<EOF
order hosts,bind
multi
EOF

    # replace resolv.conf
    cp $NETPATH/resolv.conf $NETPATH/resolv.conf.orig
    cat > $NETPATH/resolv.conf <<EOF
domain frop.org
nameserver 10.0.2.3
EOF
elif [ -f "$ETCPATH/rc.net" ]; then
    # Uses SLS's non-standard network configuration via /etc/hosts
    echo '### Configuring networking via hosts...'

    cp $ETCPATH/hosts $ETCPATH/hosts.orig
	# Note: tab must separate IP and hostnames below, not spaces
    sed 's/.*darkstar$/10.0.2.10	darkstar/' $ETCPATH/hosts > $ETCPATH/hosts.1
    sed 's/.*network$/10.0.2.0	network/' $ETCPATH/hosts.1 > $ETCPATH/hosts
    sed 's/.*router$/10.0.2.2	router/' $ETCPATH/hosts > $ETCPATH/hosts.1
    mv $ETCPATH/hosts.1 $ETCPATH/hosts
fi