debian_091_extract_base() {
    echo "### Installing base system to $ROOTDEV..."
    cd "$ROOTMOUNT"
    zcat < "$INSTMOUNT/basedsk1.img" 2>/dev/null | cpio -dimV
    zcat < "$INSTMOUNT/basedsk2.img" 2>/dev/null | cpio -dimV
    mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
}

debian_091_replace_rootdev() {
    sed "s|/dev/hda3|$ROOTDEV|g" "$1" > "$ROOTMOUNT/tmp/$2"
    mv "$ROOTMOUNT/tmp/$2" "$1"
}

debian_091_configure_init() {
    echo "### Configuring init scripts for $ROOTDEV..."
    debian_091_replace_rootdev "$ROOTMOUNT/etc/rc.d/rc.S" rc.S
    chmod 754 "$ROOTMOUNT/etc/rc.d/rc.S"
    debian_091_replace_rootdev "$ROOTMOUNT/etc/rc.d/rc.K" rc.K
    chmod 754 "$ROOTMOUNT/etc/rc.d/rc.K"
}

debian_091_configure_lilo() {
    echo "### Configuring lilo for $ROOTDEV..."
    "$ROOTMOUNT/usr/sbin/rdev" "$ROOTMOUNT/vmlinuz" "$ROOTDEV"
    "$ROOTMOUNT/usr/sbin/rdev" -R "$ROOTMOUNT/vmlinuz" 1
    "$ROOTMOUNT/usr/sbin/rdev" -v "$ROOTMOUNT/vmlinuz" -1

    sed "s|/dev/hda3|$ROOTDEV|g" "$ROOTMOUNT/etc/lilo.conf" |
      sed "s|read-only|#read-only|g" |
      sed "s|delay=20|#delay=20|g" > "$ROOTMOUNT/tmp/lilo.conf"
    mv "$ROOTMOUNT/tmp/lilo.conf" "$ROOTMOUNT/etc/lilo.conf"
    "$ROOTMOUNT/sbin/lilo" -r "$ROOTMOUNT" -C /etc/lilo.conf
}

debian_091_install_setup_hook() {
    "$ROOTMOUNT/bin/cp" "$INSTMOUNT/autoinst.d/autoconf.sh" "$ROOTMOUNT/sbin/setup.sh"
    chmod 755 "$ROOTMOUNT/sbin/setup.sh"
}

_debian_091_install_base() {
    debian_091_extract_base
    debian_091_configure_init
    debian_091_configure_lilo
    debian_091_install_setup_hook
}

debian_091_install_one_package() {
    PKG=$(basename "$1" .deb)
    echo "installing $PKG..."
    (cd /; zcat "$1" 2>>/var/adm/dpkg/dpkg.log | cpio -dim) 2> /dev/null
    if [ -f "/var/adm/dpkg/perm/$PKG.perm" ]; then
        fixperms -q "$PKG" 2> /dev/null
    fi
}

debian_091_run_package_scripts() {
    for INST in `ls /var/adm/dpkg/inst/*.inst`; do
        egrep -q '\<read\>' "$INST"
        if [ $? -ne 0 ]; then
            sh "$INST"
        fi
        rm -f "$INST"
    done
}

_debian_091_install_packages() {
    echo "### Installing packages..."

    find "$INSTMOUNT" -iname '*.deb' | sort | while read FILE; do
        debian_091_install_one_package "$FILE"
    done

    debian_091_run_package_scripts
}