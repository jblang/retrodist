# shellcheck shell=sh
debian_gzip_extract() {
    if [ -x /bin/gunzip ] || [ -x /usr/bin/gunzip ]; then
        log_debug "Using gunzip for compressed archive extraction"
        gunzip
    else
        log_debug "Using zcat for compressed archive extraction"
        zcat
    fi
}

debian_install_first_boot_init() {
    if [ -f "$ROOTMOUNT/etc/inittab" ]; then
        log_info "Creating backup file: $ROOTMOUNT/etc/inittab.real"
        mv "$ROOTMOUNT/etc/inittab" "$ROOTMOUNT/etc/inittab.real"
    else
        log_info "Moving $ROOTMOUNT/etc/init.d/inittab to $ROOTMOUNT/etc/inittab.real"
        mv "$ROOTMOUNT/etc/init.d/inittab" "$ROOTMOUNT/etc/inittab.real"
    fi
    log_info "Creating file: $ROOTMOUNT/etc/inittab"
    cp /etc/init_tab "$ROOTMOUNT/etc/inittab"
    chmod 755 "$ROOTMOUNT/etc/inittab"
    chown root.root "$ROOTMOUNT/etc/inittab"
}

debian_copy_base_configuration_hooks() {
    if [ -f /etc/root.sh.tar.gz ]; then
        log_info "Using root.sh.tar.gz configuration hook"
        mkdir -p "$ROOTMOUNT/root"
        if [ ! -f "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK.real" ]; then
            log_info "Creating backup file: $ROOTMOUNT/root/$DEBIAN_ROOT_HOOK.real"
            mv "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK" "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK.real"
        fi
        log_info "Extracting configuration hook archive into $ROOTMOUNT/root"
        (
            cd "$ROOTMOUNT/root" &&
                debian_gzip_extract </etc/root.sh.tar.gz | star
        )
        chown -R root.root "$ROOTMOUNT/root"
    else
        log_info "Using plain root/setup configuration hooks"
        log_info "Creating file: $ROOTMOUNT/root/$DEBIAN_ROOT_HOOK"
        cp /etc/root.sh "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK"
        log_info "Creating file: $ROOTMOUNT/sbin/setup.sh"
        cp /etc/setup.sh "$ROOTMOUNT/sbin/setup.sh"
        chmod 755 "$ROOTMOUNT/root/$DEBIAN_ROOT_HOOK"
        chmod 755 "$ROOTMOUNT/sbin/setup.sh"
    fi
}

debian_extract_base_system() {
    log_info "Installing base system to $ROOTDEV..."
    # cd must succeed before extracting: star writes into the current directory,
    # so a failed cd would unpack the base system into the wrong filesystem.
    cd "$ROOTMOUNT" || die "Unable to cd to $ROOTMOUNT for base system extraction."
    if [ -z "$DEBIAN_BASE_TARBALL" ]; then
        log_error "DEBIAN_BASE_TARBALL is not set."
        exit 1
    fi
    if [ ! -f "$INSTMOUNT/$DEBIAN_BASE_TARBALL" ]; then
        die "Base system tarball not found: $INSTMOUNT/$DEBIAN_BASE_TARBALL"
    fi
    debian_gzip_extract <"$INSTMOUNT/$DEBIAN_BASE_TARBALL" | star
    if [ ! -f "$ROOTMOUNT/fstab.tmp" ]; then
        die "Base system extraction did not produce $ROOTMOUNT/fstab.tmp."
    fi
    log_info "Creating file: $ROOTMOUNT/etc/fstab"
    mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
}

debian_install_boot_floppy_kernel() {
    log_info "Installing boot kernel..."
    cd "$INSTMOUNT/bootflop" || die "Unable to cd to $INSTMOUNT/bootflop."
    ./install.sh "$ROOTMOUNT" || die "Boot floppy kernel install failed."
    cd "$ROOTMOUNT" || die "Unable to cd back to $ROOTMOUNT."
}

debian_install_driver_modules() {
    if [ ! -f "$INSTMOUNT/drivers/install.sh" ]; then
        return 0
    fi

    log_info "Installing driver modules..."
    cd "$INSTMOUNT/drivers" || die "Unable to cd to $INSTMOUNT/drivers."
    sh ./install.sh "$ROOTMOUNT" || die "Driver module install failed."
    cd "$ROOTMOUNT" || die "Unable to cd back to $ROOTMOUNT."
}

debian_run_lilo() {
    (
        export LD_LIBRARY_PATH="$ROOTMOUNT/lib:$ROOTMOUNT/usr/lib"
        "$ROOTMOUNT/sbin/lilo" -r "$ROOTMOUNT" >/dev/null 2>&1
    )
}

debian_activate_partition() {
    (
        export LD_LIBRARY_PATH="$ROOTMOUNT/lib:$ROOTMOUNT/usr/lib"
        "$ROOTMOUNT/sbin/activate" "$1" "$2" >/dev/null 2>&1
    )
}

debian_install_lilo() {
    log_info "Installing LILO for $ROOTDEV..."
    log_info "Creating file: $ROOTMOUNT/etc/lilo.conf"
    cat >"$ROOTMOUNT/etc/lilo.conf" <<EOF
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
        log_warn "LILO install failed for $ROOTDEV. Use the rescue floppy to boot."
        return 0
    fi

    BOOTDEV=$(echo "$ROOTDEV" | sed 's/[0-9][0-9]*$//')
    log_info "Installing MBR to $BOOTDEV"
    cp "$ROOTMOUNT/boot/mbr.b" "$BOOTDEV"

    BOOTPART=$(echo "$ROOTDEV" | sed -e 's/^[^0-9]*//')
    log_info "Debian boot configuration:"
    log_info "  BOOTDEV=$BOOTDEV"
    log_info "  BOOTPART=$BOOTPART"
    log_info "  ROOTDEV=$ROOTDEV"
    debian_activate_partition "$BOOTDEV" "$BOOTPART"
}

_debian_install_base() {
    log_div
    log_info "Installing Debian base system"
    PATH=/usr/bin:/bin:/usr/sbin:/sbin
    DEBIAN_ROOT_HOOK=${DEBIAN_ROOT_HOOK:-.bash_profile}
    log_info "Debian install configuration:"
    log_info "  ROOTMOUNT=$ROOTMOUNT"
    log_info "  ROOTDEV=$ROOTDEV"
    log_info "  INSTMOUNT=$INSTMOUNT"
    log_info "  DEBIAN_ROOT_HOOK=$DEBIAN_ROOT_HOOK"
    log_info "  DEBIAN_BASE_TARBALL=$DEBIAN_BASE_TARBALL"

    debian_extract_base_system

    log_div
    log_info "Configuring base system..."
    debian_install_first_boot_init

    debian_install_boot_floppy_kernel
    debian_install_driver_modules

    debian_copy_base_configuration_hooks

    _debian_kbd_config
    _debian_timezone_config

    debian_install_lilo
}

_debian_kbd_config() {
    # Only normalize the keyboard config the base actually shipped. 1.1 ships
    # /etc/kbd/config with template values KEYMAP=N/SOFTFONT=N that crash 0kbd;
    # 1.2/1.3 ship no /etc/kbd/config (and no 0kbd), so there is nothing to do.
    if [ ! -f "$ROOTMOUNT/etc/kbd/config" ]; then
        log_debug "No /etc/kbd/config in base; skipping keyboard configuration"
        return 0
    fi
    DEBIAN_KEYMAP=${DEBIAN_KEYMAP:-NONE}
    DEBIAN_SOFTFONT=${DEBIAN_SOFTFONT:-NONE}
    log_info "Configuring /etc/kbd/config (KEYMAP=$DEBIAN_KEYMAP SOFTFONT=$DEBIAN_SOFTFONT)..."
    cat >"$ROOTMOUNT/etc/kbd/config" <<EOF
CONSOLE=/dev/tty0
TERM=linux
KEYMAP=$DEBIAN_KEYMAP
SOFTFONT=$DEBIAN_SOFTFONT
EOF
}

_debian_timezone_config() {
    DEBIAN_TIMEZONE=${DEBIAN_TIMEZONE:-America/Los_Angeles}
    if [ ! -f "$ROOTMOUNT/usr/lib/zoneinfo/$DEBIAN_TIMEZONE" ]; then
        log_warn "Timezone $DEBIAN_TIMEZONE not found under /usr/lib/zoneinfo; leaving shipped default"
        return 0
    fi
    log_info "Configuring timezone: $DEBIAN_TIMEZONE"
    echo "$DEBIAN_TIMEZONE" >"$ROOTMOUNT/etc/timezone"
    ln -sf "/usr/lib/zoneinfo/$DEBIAN_TIMEZONE" "$ROOTMOUNT/etc/localtime"
}
