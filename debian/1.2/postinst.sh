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

# Rex's X packages install shared libraries in /usr/X11R6/lib, but do not add
# that directory to the dynamic linker's search path.  Without this, fvwm
# cannot load libXpm.so.4 even though xpm4.7 installed it successfully.
X11_LD_LIBRARY_PATH=/usr/X11R6/lib
X11_LD_LIBRARY_FOUND=
if [ -f /etc/ld.so.conf ]; then
    while read X11_LD_LIBRARY_ENTRY; do
        if [ "$X11_LD_LIBRARY_ENTRY" = "$X11_LD_LIBRARY_PATH" ]; then
            X11_LD_LIBRARY_FOUND=1
        fi
    done </etc/ld.so.conf
fi
if [ -z "$X11_LD_LIBRARY_FOUND" ]; then
    echo "$X11_LD_LIBRARY_PATH" >> /etc/ld.so.conf
fi
for X11_LDCONFIG in /sbin/ldconfig /usr/sbin/ldconfig; do
    if [ -x "$X11_LDCONFIG" ]; then
        "$X11_LDCONFIG"
        break
    fi
done
