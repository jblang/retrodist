PATH=/usr/bin:/bin:/usr/sbin:/sbin

set_file_mode() {
    chown root.root $1
    chmod 644 $1
}

write_network_configuration() {
    echo $HOSTNAME > $ROOTMOUNT/etc/hostname
    set_file_mode $ROOTMOUNT/etc/hostname

    echo "localnet	$NETWORK" > $ROOTMOUNT/etc/networks
    set_file_mode $ROOTMOUNT/etc/networks

    if [ -n "$DOMAINNAME" ] && [ "$DOMAINNAME" != "none" ]; then
        cat > $ROOTMOUNT/etc/resolv.conf <<EOF
domain $DOMAINNAME
search $DOMAINNAME
EOF
        if [ -n "$NAMESERVER" ] && [ "$NAMESERVER" != "none" ]; then
            echo "nameserver	$NAMESERVER" >> $ROOTMOUNT/etc/resolv.conf
        fi
        set_file_mode $ROOTMOUNT/etc/resolv.conf
    fi

    cat > $ROOTMOUNT/etc/init.d/network <<EOF
#!	/bin/sh
ifconfig lo 127.0.0.1
route add -net 127.0.0.0
IPADDR=$IPADDR
NETMASK=$NETMASK
NETWORK=$NETWORK
BROADCAST=$BROADCAST
GATEWAY=$GATEWAY
ifconfig eth0 \${IPADDR} netmask \${NETMASK} broadcast \${BROADCAST}
route add -net \${NETWORK}
route add default gw \${GATEWAY} metric 1
EOF
    set_file_mode $ROOTMOUNT/etc/init.d/network
    chmod 755 $ROOTMOUNT/etc/init.d/network

    cat > $ROOTMOUNT/etc/hosts <<EOF
127.0.0.1	localhost
$IPADDR		$HOSTNAME	$HOSTNAME.$DOMAINNAME
EOF
    set_file_mode $ROOTMOUNT/etc/hosts
}

# unpack the base system
echo "### Installing base system to $ROOTDEV..."
cd $ROOTMOUNT
gunzip < $INSTMOUNT/base1_1.tgz | star
mv $ROOTMOUNT/fstab.tmp $ROOTMOUNT/etc/fstab

# install the boot kernel from the install floppy
echo "### Installing boot kernel..."
mkdir -p /floppy
mount -o ro -t msdos /dev/fd0 /floppy
cd /floppy
./install.sh $ROOTMOUNT
cd $ROOTMOUNT
umount /floppy

echo "### Configuring base system..."
cp /etc/root.sh $ROOTMOUNT/root/.configure
chmod 755 $ROOTMOUNT/root/.configure
cp /etc/setup.sh $ROOTMOUNT/sbin/setup.sh
chmod 755 $ROOTMOUNT/sbin/setup.sh
rm -f $ROOTMOUNT/sbin/unconfigured.sh

echo "### Configuring network..."
write_network_configuration

echo "### Installing LILO for $ROOTDEV..."
cat > $ROOTMOUNT/etc/lilo.conf <<EOF
boot=$ROOTDEV
root=$ROOTDEV
compact
install=/boot/boot.b
map=/boot/map
vga=normal
delay=20
image=/vmlinuz
label=Linux
read-only
EOF
chmod 644 $ROOTMOUNT/etc/lilo.conf
(export LD_LIBRARY_PATH="$ROOTMOUNT/lib:$ROOTMOUNT/usr/lib"; \
  $ROOTMOUNT/sbin/lilo -r $ROOTMOUNT >/dev/null)

echo "### Installing MBR..."
BOOTDEV=$(echo $ROOTDEV | sed -e 's/[0-9]$//')
cp $ROOTMOUNT/boot/mbr.b $BOOTDEV

echo "### Setting active partition..."
BOOTPART=$(echo $ROOTDEV | sed -e 's/^[^0-9]*//')
(export LD_LIBRARY_PATH="$ROOTMOUNT/lib:$ROOTMOUNT/usr/lib"; \
  $ROOTMOUNT/sbin/activate $BOOTDEV $BOOTPART)
