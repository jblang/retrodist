# Enable networking on eth0
if [ -d "$ROOTMOUNT/conf/net" ]; then
    ETCPATH=$ROOTMOUNT/conf/net
    RCPATH=$ETCPATH
else
    ETCPATH=$ROOTMOUNT/etc
    RCPATH=$ETCPATH/rc.d
fi
if [ -f "$RCPATH/rc.inet1" ]; then
    echo '## Configuring networking...'
    if [ -x "$ROOTMOUNT/sbin/ifconfig" ]; then
        IFCONFIG="/sbin/ifconfig"
        ROUTE="/sbin/route"
    elif [ -x "$ROOTMOUNT/etc/ifconfig" ]; then
        IFCONFIG="/etc/ifconfig"
        ROUTE="/etc/route"
    fi

    # bring up eth0 in rc.inet1
    cp $RCPATH/rc.inet1 $RCPATH/rc.inet1.orig
    cat > $RCPATH/rc.inet1 <<EOF
#! /bin/sh
#
# rc.inet1      This shell script boots up the base INET system.
#
# Version:      @(#)/etc/rc.d/rc.inet1  1.01    05/27/93
#

HOSTNAME=`hostname`

# Attach the loopback device.
$IFCONFIG lo 127.0.0.1
$ROUTE add 127.0.0.1

# IF YOU HAVE AN ETHERNET CONNECTION, use these lines below to configure the 
# eth0 interface. If you're only using loopback or SLIP, don't include the
# rest of the lines in this file.

# Edit for your setup.
IPADDR="$IPADDR"        # REPLACE with YOUR IP address!
NETMASK="$NETMASK"      # REPLACE with YOUR netmask!
NETWORK="$NETWORK"      # REPLACE with YOUR network address!
BROADCAST="$BROADCAST"  # REPLACE with YOUR broadcast address, if you
                        # have one. If not, leave blank and edit below.
GATEWAY="$GATEWAY"      # REPLACE with YOUR gateway address!

# Uncomment ONLY ONE of the three lines below. If one doesn't work, try again.
# $IFCONFIG eth0 \${IPADDR} netmask \${NETMASK} broadcast \${BROADCAST}
$IFCONFIG eth0 \${IPADDR} broadcast \${BROADCAST} netmask \${NETMASK}
# $IFCONFIG eth0 \${IPADDR} netmask \${NETMASK} 

# Uncomment these to set up your IP routing table.
$ROUTE -n add \${NETWORK}
$ROUTE add default gw \${GATEWAY} metric 1

# End of rc.inet1
EOF

    # add hostname to hosts
    cp $ETCPATH/hosts $ETCPATH/hosts.orig
    cat > $ETCPATH/hosts <<EOF
#
# hosts         This file describes a number of hostname-to-address
#               mappings for the TCP/IP subsystem.  It is mostly
#               used at boot time, when no name servers are running.
#               On small systems, this file can be used instead of a
#               "named" name server.  Just add the names, addresses
#               and any aliases to this file...
#
# Version:      @(#)/etc/hosts          2.00    04/30/93
#
# Author:       Fred N. van Kempen, <waltje@uwalt.nl.mugnet.org>
#

# For loopbacking.
127.0.0.1       darkstar.frop.org darkstar localhost
$IPADDR $HOSTNAME.$DOMAINNAME $HOSTNAME

# End of hosts.
EOF
    
    # replace host.conf
    cp $ETCPATH/host.conf $ETCPATH/host.conf.orig
    cat > $ETCPATH/host.conf <<EOF
order hosts, bind
multi on
EOF

    # replace resolv.conf
    cp $ETCPATH/resolv.conf $ETCPATH/resolv.conf.orig
    cat > $ETCPATH/resolv.conf <<EOF
domain $DOMAINNAME
nameserver $NAMESERVER
EOF
elif [ -f "$ETCPATH/rc.net" ]; then
    # Uses SLS's non-standard network configuration via /etc/hosts
    echo '## Configuring networking via hosts...'

    cp $ETCPATH/hosts $ETCPATH/hosts.orig
	# Note: tab must separate IP and hostnames below, not spaces
    sed "s/.*$HOSTNAME$/$IPADDR	$HOSTNAME/" $ETCPATH/hosts > $ETCPATH/hosts.1
    sed "s/.*network$/$NETWORK	network/" $ETCPATH/hosts.1 > $ETCPATH/hosts
    sed "s/.*router$/$GATEWAY	router/" $ETCPATH/hosts > $ETCPATH/hosts.1
    mv $ETCPATH/hosts.1 $ETCPATH/hosts
fi