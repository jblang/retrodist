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
        cp /etc/unconf.sh $TARGETMOUNT/sbin/unconfigured.sh
    fi

    if [ -f "$TARGETMOUNT/etc/inittab" ]; then
        mv "$TARGETMOUNT/etc/inittab" "$TARGETMOUNT/etc/inittab.real"
    elif [ -n "$DEBIAN_INITTAB_FALLBACK" ] && [ -f "$TARGETMOUNT/$DEBIAN_INITTAB_FALLBACK" ]; then
        mv "$TARGETMOUNT/$DEBIAN_INITTAB_FALLBACK" "$TARGETMOUNT/etc/inittab.real"
    fi

    if [ -f /etc/init_tab ]; then
        cp /etc/init_tab $TARGETMOUNT/etc/inittab
    elif [ -f "$TARGETMOUNT/etc/inittab.real" ]; then
        cp "$TARGETMOUNT/etc/inittab.real" "$TARGETMOUNT/etc/inittab"
    fi

    if [ -f "$TARGETMOUNT/etc/inittab" ]; then
        chmod 755 "$TARGETMOUNT/etc/inittab"
        chown root.root "$TARGETMOUNT/etc/inittab"
    fi
    if [ -f "$TARGETMOUNT/sbin/unconfigured.sh" ]; then
        chmod 755 "$TARGETMOUNT/sbin/unconfigured.sh"
        chown root.root "$TARGETMOUNT/sbin/unconfigured.sh"
    fi
}

prepare_base_system_093r6() {
    if [ -f "$TARGETMOUNT/etc/init.d/inittab" ] && [ ! -f "$TARGETMOUNT/etc/inittab" ]; then
        cp "$TARGETMOUNT/etc/init.d/inittab" "$TARGETMOUNT/etc/inittab"
        set_file_mode "$TARGETMOUNT/etc/inittab"
    fi
}

copy_base_configuration_hooks() {
    if [ -n "$DEBIAN_ROOT_TARBALL" ] && [ -f "$DEBIAN_ROOT_TARBALL" ]; then
        mkdir -p "$TARGETMOUNT/root"
        if [ -f "$TARGETMOUNT/root/$DEBIAN_ROOT_HOOK" ] && [ ! -f "$TARGETMOUNT/root/$DEBIAN_ROOT_HOOK.real" ]; then
            mv "$TARGETMOUNT/root/$DEBIAN_ROOT_HOOK" "$TARGETMOUNT/root/$DEBIAN_ROOT_HOOK.real"
        fi
        GZIP_EXTRACT=$(gzip_extract_cmd) || return 1
        (
            cd "$TARGETMOUNT/root" &&
            $GZIP_EXTRACT < "$DEBIAN_ROOT_TARBALL" | extract_tar_stream
        )
        chown -R root.root "$TARGETMOUNT/root"
    elif [ -f /etc/root.sh ]; then
        cp /etc/root.sh "$TARGETMOUNT/root/$DEBIAN_ROOT_HOOK"
        chmod 755 "$TARGETMOUNT/root/$DEBIAN_ROOT_HOOK"
    fi

    if [ -z "$DEBIAN_SKIP_SETUP_SH" ] && [ -f /etc/setup.sh ]; then
        cp /etc/setup.sh $TARGETMOUNT/sbin/setup.sh
        chmod 755 $TARGETMOUNT/sbin/setup.sh
    fi

    rm -f $TARGETMOUNT/sbin/unconfigured.sh
}

write_network_configuration() {
    echo $HOSTNAME > $TARGETMOUNT/etc/hostname
    set_file_mode $TARGETMOUNT/etc/hostname

    echo "localnet	$NETWORK" > $TARGETMOUNT/etc/networks
    set_file_mode $TARGETMOUNT/etc/networks

    if [ -n "$DOMAINNAME" ] && [ "$DOMAINNAME" != "none" ]; then
        cat > $TARGETMOUNT/etc/resolv.conf <<EOF
domain $DOMAINNAME
search $DOMAINNAME
EOF
        if [ -n "$NAMESERVER" ] && [ "$NAMESERVER" != "none" ]; then
            echo "nameserver	$NAMESERVER" >> $TARGETMOUNT/etc/resolv.conf
        fi
        set_file_mode $TARGETMOUNT/etc/resolv.conf
    fi

    cat > $TARGETMOUNT/etc/init.d/network <<EOF
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
        cat >> $TARGETMOUNT/etc/init.d/network <<EOF
if ifconfig eth0 \${IPADDR} netmask \${NETMASK} broadcast \${BROADCAST} >/dev/null 2>&1; then
route add -net \${NETWORK}
route add default gw \${GATEWAY} metric 1
fi
EOF
    else
        cat >> $TARGETMOUNT/etc/init.d/network <<EOF
ifconfig eth0 \${IPADDR} netmask \${NETMASK} broadcast \${BROADCAST}
route add -net \${NETWORK}
route add default gw \${GATEWAY} metric 1
EOF
    fi
    set_file_mode $TARGETMOUNT/etc/init.d/network
    chmod 755 $TARGETMOUNT/etc/init.d/network

    cat > $TARGETMOUNT/etc/hosts <<EOF
127.0.0.1	localhost
$IPADDR		$HOSTNAME	$HOSTNAME.$DOMAINNAME
EOF
    set_file_mode $TARGETMOUNT/etc/hosts
}

extract_base_system() {
    echo "### Installing base system to $ROOTDEV..."
    cd $TARGETMOUNT
    GZIP_EXTRACT=$(gzip_extract_cmd) || return 1
    if [ -n "$DEBIAN_BASE_TARBALL" ]; then
        $GZIP_EXTRACT < "$SOURCEMOUNT/$DEBIAN_BASE_TARBALL" | extract_tar_stream
    else
        for DISK in $DEBIAN_BASE_DISKS; do
            dd if=$SOURCEMOUNT/$DISK.img bs=512 skip=1 2>/dev/null
        done | $GZIP_EXTRACT | extract_tar_stream
    fi
    mv $TARGETMOUNT/fstab.tmp $TARGETMOUNT/etc/fstab
}

install_boot_floppy_kernel() {
    if [ -z "$DEBIAN_INSTALL_BOOT_FLOPPY" ]; then
        return 0
    fi

    echo "### Installing boot kernel..."
    mkdir -p /floppy
    mount -o ro -t msdos /dev/fd0 /floppy
    cd /floppy
    ./install.sh $TARGETMOUNT
    cd $TARGETMOUNT
    umount /floppy
}

install_driver_modules() {
    if [ -z "$DEBIAN_INSTALL_DRIVERS" ] || [ ! -f "$SOURCEMOUNT/drivers/install.sh" ]; then
        return 0
    fi

    echo "### Installing driver modules..."
    cd "$SOURCEMOUNT/drivers"
    sh ./install.sh "$TARGETMOUNT"
    cd "$TARGETMOUNT"
}

configure_driver_modules() {
    if [ -z "$DEBIAN_CONFIGURE_MODULES" ]; then
        return 0
    fi

    if [ -f "$TARGETMOUNT/etc/modules" ]; then
        echo ne >> "$TARGETMOUNT/etc/modules"
    fi

    if [ -f "$TARGETMOUNT/etc/conf.modules" ]; then
        echo 'alias eth0 ne' >> "$TARGETMOUNT/etc/conf.modules"
        echo 'options ne io=0x300 irq=9' >> "$TARGETMOUNT/etc/conf.modules"
    fi

    if [ -f "$TARGETMOUNT/etc/modules" ] && [ ! -f "$TARGETMOUNT/etc/modules.old" ]; then
        cp "$TARGETMOUNT/etc/modules" "$TARGETMOUNT/etc/modules.old"
    fi
}

install_lilo() {
    if [ -n "$DEBIAN_OPTIONAL_LILO" ]; then
        if [ ! -x $TARGETMOUNT/sbin/lilo ] || [ ! -x $TARGETMOUNT/sbin/activate ] || [ ! -f $TARGETMOUNT/boot/mbr.b ]; then
            return 0
        fi
    fi

    echo "### Installing LILO for $ROOTDEV..."
    cat > $TARGETMOUNT/etc/lilo.conf <<EOF
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
    chmod 644 $TARGETMOUNT/etc/lilo.conf
    (export LD_LIBRARY_PATH="$TARGETMOUNT/lib:$TARGETMOUNT/usr/lib"; \
      $TARGETMOUNT/sbin/lilo -r $TARGETMOUNT >/dev/null)

    echo "### Installing MBR..."
    BOOTDEV=$(echo $ROOTDEV | sed -e 's/[0-9]$//')
    cp $TARGETMOUNT/boot/mbr.b $BOOTDEV

    echo "### Setting active partition..."
    BOOTPART=$(echo $ROOTDEV | sed -e 's/^[^0-9]*//')
    (export LD_LIBRARY_PATH="$TARGETMOUNT/lib:$TARGETMOUNT/usr/lib"; \
      $TARGETMOUNT/sbin/activate $BOOTDEV $BOOTPART)
}
