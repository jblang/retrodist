debian_091_extract_base() {
    log_info "Installing base system to $ROOTDEV..."
    cd "$ROOTMOUNT"
    zcat < "$INSTMOUNT/basedsk1.img" 2>/dev/null | cpio -dimV
    zcat < "$INSTMOUNT/basedsk2.img" 2>/dev/null | cpio -dimV
    log_info "Creating file: $ROOTMOUNT/etc/fstab"
    mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
}

debian_091_replace_rootdev() {
    log_info "Creating file: $ROOTMOUNT/tmp/$2"
    sed "s|/dev/hda3|$ROOTDEV|g" "$1" > "$ROOTMOUNT/tmp/$2"
    log_info "Creating file: $1"
    mv "$ROOTMOUNT/tmp/$2" "$1"
}

debian_091_configure_init() {
    log_info "Configuring init scripts for $ROOTDEV..."
    debian_091_replace_rootdev "$ROOTMOUNT/etc/rc.d/rc.S" rc.S
    chmod 754 "$ROOTMOUNT/etc/rc.d/rc.S"
    debian_091_replace_rootdev "$ROOTMOUNT/etc/rc.d/rc.K" rc.K
    chmod 754 "$ROOTMOUNT/etc/rc.d/rc.K"
}

debian_091_configure_lilo() {
    log_info "Configuring lilo for $ROOTDEV..."
    "$ROOTMOUNT/usr/sbin/rdev" "$ROOTMOUNT/vmlinuz" "$ROOTDEV"
    "$ROOTMOUNT/usr/sbin/rdev" -R "$ROOTMOUNT/vmlinuz" 1
    "$ROOTMOUNT/usr/sbin/rdev" -v "$ROOTMOUNT/vmlinuz" -1

    log_info "Creating file: $ROOTMOUNT/tmp/lilo.conf"
    sed "s|/dev/hda3|$ROOTDEV|g" "$ROOTMOUNT/etc/lilo.conf" |
      sed "s|read-only|#read-only|g" |
      sed "s|delay=20|#delay=20|g" > "$ROOTMOUNT/tmp/lilo.conf"
    log_info "Creating file: $ROOTMOUNT/etc/lilo.conf"
    mv "$ROOTMOUNT/tmp/lilo.conf" "$ROOTMOUNT/etc/lilo.conf"
    "$ROOTMOUNT/sbin/lilo" -r "$ROOTMOUNT" -C /etc/lilo.conf
}

debian_091_install_setup_hook() {
    log_info "Creating file: $ROOTMOUNT/sbin/setup.sh"
    "$ROOTMOUNT/bin/cp" "$INSTMOUNT/autoinst.d/autoconf.sh" "$ROOTMOUNT/sbin/setup.sh"
    chmod 755 "$ROOTMOUNT/sbin/setup.sh"
}

_debian_091_install_base() {
    log_info "Installing Debian 0.91 base system"
    log_info "Debian 0.91 install configuration:"
    log_info "  ROOTMOUNT=$ROOTMOUNT"
    log_info "  ROOTDEV=$ROOTDEV"
    log_info "  INSTMOUNT=$INSTMOUNT"
    debian_091_extract_base
    debian_091_configure_init
    debian_091_configure_lilo
    debian_091_install_setup_hook
}

debian_091_install_one_package() {
    PKG=$(basename "$1" .deb)
    log_info "Installing $PKG..."
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
    log_div
    log_info "Installing Debian 0.91 packages"
    log_info "Searching for packages under $INSTMOUNT/packages"

    find "$INSTMOUNT/packages" -iname '*.deb' | sort | while read FILE; do
        debian_091_install_one_package "$FILE"
    done

    debian_091_run_package_scripts
}
