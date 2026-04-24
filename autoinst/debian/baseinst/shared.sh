PATH=/usr/bin:/bin:/usr/sbin:/sbin

set_file_mode() {
    chown root.root $1
    chmod 644 $1
}

has_cmd() {
    [ -x "/bin/$1" ] || [ -x "/usr/bin/$1" ] || [ -x "/sbin/$1" ] || [ -x "/usr/sbin/$1" ]
}

gzip_extract_cmd() {
    if has_cmd gunzip; then
        echo gunzip
    elif has_cmd zcat; then
        echo zcat
    else
        return 1
    fi
}

extract_tar_stream() {
    if [ -n "$DEBIAN_TAR_EXTRACTOR" ]; then
        set -- $DEBIAN_TAR_EXTRACTOR
        "$@"
    elif has_cmd star; then
        star
    elif has_cmd tar; then
        tar -xpf -
    else
        return 1
    fi
}

prepare_base_system_dinstall() {
    if [ -f /etc/unconf.sh ]; then
        cp /etc/unconf.sh $ROOTMOUNT/sbin/unconfigured.sh
    fi

    if [ -f "$ROOTMOUNT/etc/inittab" ]; then
        mv "$ROOTMOUNT/etc/inittab" "$ROOTMOUNT/etc/inittab.real"
    elif [ -n "$DEBIAN_INITTAB_FALLBACK" ] && [ -f "$ROOTMOUNT/$DEBIAN_INITTAB_FALLBACK" ]; then
        mv "$ROOTMOUNT/$DEBIAN_INITTAB_FALLBACK" "$ROOTMOUNT/etc/inittab.real"
    fi

    if [ -f /etc/init_tab ]; then
        cp /etc/init_tab $ROOTMOUNT/etc/inittab
    elif [ -f "$ROOTMOUNT/etc/inittab.real" ]; then
        cp "$ROOTMOUNT/etc/inittab.real" "$ROOTMOUNT/etc/inittab"
    fi

    if [ -f "$ROOTMOUNT/etc/inittab" ]; then
        chmod 755 "$ROOTMOUNT/etc/inittab"
        chown root.root "$ROOTMOUNT/etc/inittab"
    fi
    if [ -f "$ROOTMOUNT/sbin/unconfigured.sh" ]; then
        chmod 755 "$ROOTMOUNT/sbin/unconfigured.sh"
        chown root.root "$ROOTMOUNT/sbin/unconfigured.sh"
    fi
}

prepare_base_system_093r6() {
    if [ -f "$ROOTMOUNT/etc/init.d/inittab" ] && [ ! -f "$ROOTMOUNT/etc/inittab" ]; then
        cp "$ROOTMOUNT/etc/init.d/inittab" "$ROOTMOUNT/etc/inittab"
        set_file_mode "$ROOTMOUNT/etc/inittab"
    fi
}

copy_base_configuration_hooks() {
    if [ -n "$DEBIAN_ROOT_TARBALL" ] && [ -f "$DEBIAN_ROOT_TARBALL" ]; then
        mkdir -p "$ROOTMOUNT/root"
        if [ -f "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK" ] && [ ! -f "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK.real" ]; then
            mv "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK" "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK.real"
        fi
        GZIP_EXTRACT=$(gzip_extract_cmd) || return 1
        (
            cd "$ROOTMOUNT/root" &&
            $GZIP_EXTRACT < "$DEBIAN_ROOT_TARBALL" | extract_tar_stream
        )
        chown -R root.root "$ROOTMOUNT/root"
    elif [ -f /etc/root.sh ]; then
        cp /etc/root.sh "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK"
        chmod 755 "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK"
    fi

    if [ -z "$DEBIAN_SKIP_SETUP_SH" ] && [ -f /etc/setup.sh ]; then
        cp /etc/setup.sh $ROOTMOUNT/sbin/setup.sh
        chmod 755 $ROOTMOUNT/sbin/setup.sh
    fi

    rm -f $ROOTMOUNT/sbin/unconfigured.sh
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
EOF
    if [ -n "$DEBIAN_GUARD_ETH0" ]; then
        cat >> $ROOTMOUNT/etc/init.d/network <<EOF
if ifconfig eth0 \${IPADDR} netmask \${NETMASK} broadcast \${BROADCAST} >/dev/null 2>&1; then
route add -net \${NETWORK}
route add default gw \${GATEWAY} metric 1
fi
EOF
    else
        cat >> $ROOTMOUNT/etc/init.d/network <<EOF
ifconfig eth0 \${IPADDR} netmask \${NETMASK} broadcast \${BROADCAST}
route add -net \${NETWORK}
route add default gw \${GATEWAY} metric 1
EOF
    fi
    set_file_mode $ROOTMOUNT/etc/init.d/network
    chmod 755 $ROOTMOUNT/etc/init.d/network

    cat > $ROOTMOUNT/etc/hosts <<EOF
127.0.0.1	localhost
$IPADDR		$HOSTNAME	$HOSTNAME.$DOMAINNAME
EOF
    set_file_mode $ROOTMOUNT/etc/hosts
}

extract_base_system() {
    echo "### Installing base system to $ROOTDEV..."
    cd $ROOTMOUNT
    GZIP_EXTRACT=$(gzip_extract_cmd) || return 1
    if [ -n "$DEBIAN_BASE_TARBALL" ]; then
        $GZIP_EXTRACT < "$INSTMOUNT/$DEBIAN_BASE_TARBALL" | extract_tar_stream
    else
        for DISK in $DEBIAN_BASE_DISKS; do
            dd if=$INSTMOUNT/$DISK.img bs=512 skip=1 2>/dev/null
        done | $GZIP_EXTRACT | extract_tar_stream
    fi
    mv $ROOTMOUNT/fstab.tmp $ROOTMOUNT/etc/fstab
}

install_boot_floppy_kernel() {
    if [ -z "$DEBIAN_INSTALL_BOOT_FLOPPY" ]; then
        return 0
    fi

    echo "### Installing boot kernel..."
    mkdir -p /floppy
    mount -o ro -t msdos /dev/fd0 /floppy
    cd /floppy
    ./install.sh $ROOTMOUNT
    cd $ROOTMOUNT
    umount /floppy
}

install_driver_modules() {
    if [ -z "$DEBIAN_INSTALL_DRIVERS" ] || [ ! -f "$INSTMOUNT/drivers/install.sh" ]; then
        return 0
    fi

    echo "### Installing driver modules..."
    cd "$INSTMOUNT/drivers"
    sh ./install.sh "$ROOTMOUNT"
    cd "$ROOTMOUNT"
}

configure_driver_modules() {
    if [ -z "$DEBIAN_CONFIGURE_MODULES" ]; then
        return 0
    fi

    if [ -f "$ROOTMOUNT/etc/modules" ]; then
        echo ne >> "$ROOTMOUNT/etc/modules"
    fi

    if [ -f "$ROOTMOUNT/etc/conf.modules" ]; then
        echo 'alias eth0 ne' >> "$ROOTMOUNT/etc/conf.modules"
        echo 'options ne io=0x300 irq=9' >> "$ROOTMOUNT/etc/conf.modules"
    fi

    if [ -f "$ROOTMOUNT/etc/modules" ] && [ ! -f "$ROOTMOUNT/etc/modules.old" ]; then
        cp "$ROOTMOUNT/etc/modules" "$ROOTMOUNT/etc/modules.old"
    fi
}

install_lilo() {
    if [ -n "$DEBIAN_OPTIONAL_LILO" ]; then
        if [ ! -x $ROOTMOUNT/sbin/lilo ] || [ ! -x $ROOTMOUNT/sbin/activate ] || [ ! -f $ROOTMOUNT/boot/mbr.b ]; then
            return 0
        fi
    fi

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
}
