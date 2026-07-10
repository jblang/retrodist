# static arp entries to fix flaky networking in 1.2:
NET_GATEWAY_HWADDR=52:55:0a:00:02:02
NET_NAMESERVER=10.0.2.3
NET_NAMESERVER_HWADDR=52:55:0a:00:02:03
NET_ARP_PATH=$(which arp)
ETC_INITD_NETWORK=/etc/init.d/network

# dinstall defines GATEWAY here but keeps the nameserver only in resolv.conf.
echo "NAMESERVER=$NET_NAMESERVER" >> $ETC_INITD_NETWORK
echo "$NET_ARP_PATH -s \$GATEWAY $NET_GATEWAY_HWADDR" >> $ETC_INITD_NETWORK
echo "$NET_ARP_PATH -s \$NAMESERVER $NET_NAMESERVER_HWADDR" >> $ETC_INITD_NETWORK

tty_config
