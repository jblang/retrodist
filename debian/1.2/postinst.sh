# Static ARP entries fix flaky networking in Debian 1.2.
for NET_ARP_PATH in /sbin/arp /usr/sbin/arp /bin/arp /usr/bin/arp; do
    if [ -x "$NET_ARP_PATH" ]; then
        break
    fi
done

# dinstall defines GATEWAY here but keeps the nameserver only in resolv.conf.
echo "NAMESERVER=$NET_NAMESERVER" >> $ETC_INITD_NETWORK
echo "$NET_ARP_PATH -s \$GATEWAY $NET_GATEWAY_HWADDR" >> $ETC_INITD_NETWORK
echo "$NET_ARP_PATH -s \$NAMESERVER $NET_NAMESERVER_HWADDR" >> $ETC_INITD_NETWORK
