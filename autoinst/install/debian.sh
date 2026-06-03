debian_gzip_extract() {
    if [ -x /bin/gunzip ] || [ -x /usr/bin/gunzip ]; then
        gunzip
    else
        zcat
    fi
}

debian_install_first_boot_init() {
    if [ -f "$ROOTMOUNT/etc/inittab" ]; then
        mv "$ROOTMOUNT/etc/inittab" "$ROOTMOUNT/etc/inittab.real"
    else
        mv "$ROOTMOUNT/etc/init.d/inittab" "$ROOTMOUNT/etc/inittab.real"
    fi
    cp /etc/init_tab "$ROOTMOUNT/etc/inittab"
    chmod 755 "$ROOTMOUNT/etc/inittab"
    chown root.root "$ROOTMOUNT/etc/inittab"
}

debian_copy_base_configuration_hooks() {
    if [ -f /etc/root.sh.tar.gz ]; then
        mkdir -p "$ROOTMOUNT/root"
        if [ ! -f "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK.real" ]; then
            mv "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK" "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK.real"
        fi
        (
            cd "$ROOTMOUNT/root" &&
            debian_gzip_extract < /etc/root.sh.tar.gz | star
        )
        chown -R root.root "$ROOTMOUNT/root"
    else
        cp /etc/root.sh "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK"
        cp /etc/setup.sh "$ROOTMOUNT/sbin/setup.sh"
        chmod 755 "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK"
        chmod 755 "$ROOTMOUNT/sbin/setup.sh"
    fi
}

debian_extract_base_system() {
    echo "### Installing base system to $ROOTDEV..."
    cd "$ROOTMOUNT"
    if [ -z "$DEBIAN_BASE_TARBALL" ]; then
        echo "DEBIAN_BASE_TARBALL is not set."
        exit 1
    fi
    debian_gzip_extract < "$INSTMOUNT/$DEBIAN_BASE_TARBALL" | star
    mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
}

debian_install_boot_floppy_kernel() {
    echo "### Installing boot kernel..."
    cd "$INSTMOUNT/bootflop"
    ./install.sh "$ROOTMOUNT"
    cd "$ROOTMOUNT"
}

debian_install_driver_modules() {
    if [ ! -f "$INSTMOUNT/drivers/install.sh" ]; then
        return 0
    fi

    echo "### Installing driver modules..."
    cd "$INSTMOUNT/drivers"
    sh ./install.sh "$ROOTMOUNT"
    cd "$ROOTMOUNT"
}

debian_configure_driver_modules() {
    if [ -z "$DEBIAN_ETH_MODULE" ]; then
        return 0
    fi

    DEBIAN_ETH_MODULE_OPTIONS=${DEBIAN_ETH_MODULE_OPTIONS:-}

    if [ ! -d "$ROOTMOUNT/lib/modules" ]; then
        return 0
    fi

    if [ ! -d "$ROOTMOUNT/etc" ]; then
        mkdir "$ROOTMOUNT/etc"
    fi

    if [ ! -f "$ROOTMOUNT/etc/modules" ]; then
        : > "$ROOTMOUNT/etc/modules"
        chmod 644 "$ROOTMOUNT/etc/modules"
    fi

    if [ ! -f "$ROOTMOUNT/etc/conf.modules" ]; then
        : > "$ROOTMOUNT/etc/conf.modules"
        chmod 644 "$ROOTMOUNT/etc/conf.modules"
    fi

    if [ ! -f "$ROOTMOUNT/etc/modules.old" ]; then
        cp "$ROOTMOUNT/etc/modules" "$ROOTMOUNT/etc/modules.old"
    fi

    if [ -n "$DEBIAN_ETH_MODULE_OPTIONS" ]; then
        echo "$DEBIAN_ETH_MODULE $DEBIAN_ETH_MODULE_OPTIONS" >> "$ROOTMOUNT/etc/modules"
    else
        echo "$DEBIAN_ETH_MODULE" >> "$ROOTMOUNT/etc/modules"
    fi

    echo "alias eth0 $DEBIAN_ETH_MODULE" >> "$ROOTMOUNT/etc/conf.modules"
    if [ -n "$DEBIAN_ETH_MODULE_OPTIONS" ]; then
        echo "options $DEBIAN_ETH_MODULE $DEBIAN_ETH_MODULE_OPTIONS" >> "$ROOTMOUNT/etc/conf.modules"
    fi
}

debian_run_lilo() {
    (export LD_LIBRARY_PATH="$ROOTMOUNT/lib:$ROOTMOUNT/usr/lib"; \
      "$ROOTMOUNT/sbin/lilo" -r "$ROOTMOUNT" >/dev/null 2>&1)
}

debian_activate_partition() {
    (export LD_LIBRARY_PATH="$ROOTMOUNT/lib:$ROOTMOUNT/usr/lib"; \
      "$ROOTMOUNT/sbin/activate" "$1" "$2" >/dev/null 2>&1)
}

debian_install_lilo() {
    echo "### Installing LILO for $ROOTDEV..."
    cat > "$ROOTMOUNT/etc/lilo.conf" <<EOF
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
    chmod 644 "$ROOTMOUNT/etc/lilo.conf"
    debian_run_lilo
    if [ $? -ne 0 ]; then
        echo "Warning: LILO install failed for $ROOTDEV. Use the rescue floppy to boot."
        return 0
    fi

    BOOTDEV=$(echo "$ROOTDEV" | sed -e 's/[0-9]$//')
    cp "$ROOTMOUNT/boot/mbr.b" "$BOOTDEV"

    BOOTPART=$(echo "$ROOTDEV" | sed -e 's/^[^0-9]*//')
    debian_activate_partition "$BOOTDEV" "$BOOTPART"
}

_debian_install_base() {
    PATH=/usr/bin:/bin:/usr/sbin:/sbin
    DEBIAN_ROOT_HOOK=${DEBIAN_ROOT_HOOK:-.bash_profile}

    debian_extract_base_system

    echo "### Configuring base system..."
    debian_install_first_boot_init

    debian_install_boot_floppy_kernel
    debian_install_driver_modules
    debian_configure_driver_modules

    debian_copy_base_configuration_hooks

    debian_install_lilo
}
