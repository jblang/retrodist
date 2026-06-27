# shellcheck shell=sh
# pkgtool-based Slackware installer helpers.

# Set Slackware release-specific admin paths and setup commands.
slackware_pkgtool_layout() {
    SLACK_ADM_DIR=$1
    SLACK_SPOOL_DIR=$2
    SLACK_TIMECONFIG=$SLACK_ADM_DIR/setup/setup.timeconfig
    SLACK_LILOCONFIG=$SLACK_ADM_DIR/setup/setup.liloconfig
    SLACK_PKGTOOL_SOURCE=$3
    SLACK_SETUP_SOURCE=$4
    log_info "Slackware pkgtool layout:"
    log_info "  ADM_DIR=$SLACK_ADM_DIR"
    log_info "  SPOOL_DIR=$SLACK_SPOOL_DIR"
    log_info "  PKGTOOL_SOURCE=$SLACK_PKGTOOL_SOURCE"
    log_info "  SETUP_SOURCE=$SLACK_SETUP_SOURCE"
}

# Install using the Slackware 1.1.1 pkgtool layout.
_slackware_pkgtool_install_111() {
    log_info "Installing Slackware with pkgtool"
    log_info "Using Slackware 1.1.1 pkgtool layout"
    slackware_pkgtool_layout usr/adm usr/spool /bin/pkgtool /bin/setup
    slackware_install_with_pkgtool
}

# Install using the later Slackware pkgtool layout.
_slackware_pkgtool_install() {
    log_div
    log_info "Installing Slackware with pkgtool"
    log_info "Using modern Slackware pkgtool layout"
    slackware_pkgtool_layout var/adm var/spool /bin/pkgtool.tty /bin/setup.tty
    slackware_install_with_pkgtool
}

# Convert selected package sets to pkgtool's #set# format.
normalize_sets() {
    if [ -z "$SETS" ] && [ -f "$INSTMOUNT/disksets.txt" ]; then
        SETS=$(cat "$INSTMOUNT/disksets.txt")
    fi
    SETS=$(echo "$SETS" | sed 's/[ ;,]/#/g')
    log_info "Slackware package sets: $SETS"
}

# Create pkgtool directories that do not already exist.
pkgtool_mkdirs() {
    for DIR in "$@"; do
        if [ ! -d "$DIR" ]; then
            log_debug "Creating directory: $DIR"
            mkdir -p "$DIR"
        fi
    done
}

# Create each setup state directory used by pkgtool.
setup_state_mkdirs() {
    for SETUPDIR in $(setup_state_dirs); do
        pkgtool_mkdirs "$SETUPDIR"
    done
}

# Print setup state directories for installer and target layouts.
setup_state_dirs() {
    echo /tmp
    echo /var/log/setup/tmp
    if [ -n "$ROOTMOUNT" ]; then
        echo "$ROOTMOUNT/var/log/setup/tmp"
    fi
}

# Write one setup state value to every setup state directory.
write_setup_state() {
    STATEFILE=$1
    STATEVALUE=$2
    setup_state_mkdirs
    for SETUPDIR in $(setup_state_dirs); do
        echo "$STATEVALUE" >"$SETUPDIR/$STATEFILE"
    done
}

# Remove one setup state file from every setup state directory.
remove_setup_state() {
    STATEFILE=$1
    for SETUPDIR in $(setup_state_dirs); do
        rm -f "$SETUPDIR/$STATEFILE"
    done
}

# Print the Slackware package tree path on the mounted CD-ROM.
find_cdrom_source_path() {
    for SOURCE in slakware slackware; do
        if [ -d "$CD_MOUNT/$SOURCE" ]; then
            echo "$CD_MOUNT/$SOURCE"
            return 0
        fi
    done
    return 1
}

# Print the staged package tree path when it exists.
find_staged_source_path() {
    if [ -d "$INSTMOUNT/packages" ]; then
        echo "$INSTMOUNT/packages"
        return 0
    fi
    return 1
}

# Print the first usable pkgtool binary path.
find_pkgtool_bin() {
    for PKGTOOL_BIN in \
        /usr/lib/setup/cpkgtool \
        /usr/lib/setup/pkgtool \
        /bin/pkgtool \
        /bin/pkgtool.tty \
        "$SLACK_PKGTOOL_SOURCE"; do
        if [ -x "$PKGTOOL_BIN" ]; then
            echo "$PKGTOOL_BIN"
            return 0
        fi
    done
    return 1
}

# Mount the CD-ROM package source and record its fstab entry.
mount_cdrom_source() {
    CD_DEVICE=${CD_DEVICE:-/dev/hdc}
    CD_MOUNT=${CD_MOUNT:-/var/adm/mount}
    log_info "CD-ROM source configuration:"
    log_info "  CD_DEVICE=$CD_DEVICE"
    log_info "  CD_MOUNT=$CD_MOUNT"
    pkgtool_mkdirs "$CD_MOUNT"

    mount -o ro -t iso9660 "$CD_DEVICE" "$CD_MOUNT" ||
        die "Unable to mount CD-ROM source $CD_DEVICE on $CD_MOUNT."

    SLACK_PKG_SOURCE=$(find_cdrom_source_path)
    if [ -z "$SLACK_PKG_SOURCE" ]; then
        log_error "Unable to find Slackware package tree on mounted CD-ROM."
        umount "$CD_MOUNT"
        exit 1
    fi

    log_info "Using mounted Slackware package source: $SLACK_PKG_SOURCE"
    SLACK_CD_SOURCE_MOUNTED=1
    SLACK_CD_FSTAB_ENTRY="$CD_DEVICE    /cdrom    iso9660    ro   1   1"
}

# Select staged tagfiles or generated .new tagfiles for pkgtool.
setup_pkgtool_tags() {
    SLACK_PKG_TAG_MODE=custom_ext
    if [ -d "$INSTMOUNT/tagfiles" ]; then
        SLACK_PKG_TAG_MODE=tagpath
        log_info "Using Slackware tagfile directory: $INSTMOUNT/tagfiles"
        write_setup_state SeTtagpath "$INSTMOUNT/tagfiles"
    else
        log_info "Using Slackware custom .new package tag extension"
    fi
}

# Tell pkgtool to use the generated .new tagfile extension.
write_pkgtool_custom_ext() {
    if [ "$SLACK_PKG_TAG_MODE" = "custom_ext" ]; then
        write_setup_state SeTtagext ".new"
        log_info "Creating file: /tmp/custom"
        echo ".new" >/tmp/custom
    fi
}

# Resolve pkgtool binary, tags, and package source.
prepare_pkgtool_source() {
    SLACK_CD_SOURCE_MOUNTED=
    SLACK_PKG_SOURCE=$(find_staged_source_path)
    SLACK_PKGTOOL_BIN=$(find_pkgtool_bin)
    if [ -z "$SLACK_PKGTOOL_BIN" ]; then
        log_error "Unable to find pkgtool binary."
        exit 1
    fi
    log_info "Using pkgtool binary: $SLACK_PKGTOOL_BIN"

    setup_pkgtool_tags

    if [ -z "$SLACK_PKG_SOURCE" ]; then
        log_info "No staged Slackware package source found; trying CD-ROM"
        mount_cdrom_source
    else
        log_info "Using staged Slackware package source: $SLACK_PKG_SOURCE"
    fi
}

# Remove temporary pkgtool state and unmount any CD source.
cleanup_pkgtool_source() {
    remove_setup_state SeTtagext
    remove_setup_state SeTtagpath
    rm -f /tmp/custom

    if [ -n "$SLACK_CD_SOURCE_MOUNTED" ]; then
        log_info "Unmounting CD-ROM source from $CD_MOUNT"
        umount "$CD_MOUNT"
    fi
}

# Move a packaged setup hook into Slackware's setup directory.
move_setup_hook() {
    if [ -f "$ROOTMOUNT/$1" ]; then
        pkgtool_mkdirs "$ROOTMOUNT/$SLACK_ADM_DIR/setup/install"
        log_info "Moving setup hook: $ROOTMOUNT/$1 -> $ROOTMOUNT/$SLACK_ADM_DIR/setup/install"
        mv "$ROOTMOUNT/$1" "$ROOTMOUNT/$SLACK_ADM_DIR/setup/install"
    fi
}

# Run pkgtool for the selected package sets.
install_pkgtool_sets() {
    log_info "Installing packages..."
    normalize_sets
    pkgtool_mkdirs "$INSTMOUNT/tmp"
    rm -f "$INSTMOUNT/tmp/tagfile"
    prepare_pkgtool_source
    write_pkgtool_custom_ext

    log_debug "pkgtool command: $SLACK_PKGTOOL_BIN -source_mounted -source_dir $SLACK_PKG_SOURCE -target_dir $ROOTMOUNT -sets #$SETS#"
    "$SLACK_PKGTOOL_BIN" -source_mounted -source_dir "$SLACK_PKG_SOURCE" -target_dir "$ROOTMOUNT" -sets "#$SETS#"
    PKGTOOL_STATUS=$?
    cleanup_pkgtool_source
    if [ $PKGTOOL_STATUS -ne 0 ]; then
        log_error "pkgtool install failed."
        exit 1
    fi
}

# Write Slackware's ROOTDEV file when missing.
write_rootdev() {
    pkgtool_mkdirs "$ROOTMOUNT/etc/rc.d"
    if [ ! -r "$ROOTMOUNT/etc/rc.d/ROOTDEV" ]; then
        log_info "Creating file: $ROOTMOUNT/etc/rc.d/ROOTDEV"
        echo "$ROOTDEV" >"$ROOTMOUNT/etc/rc.d/ROOTDEV"
        chmod 644 "$ROOTMOUNT/etc/rc.d/ROOTDEV"
    fi
}

# Install fstab and add proc and CD-ROM entries when needed.
install_fstab() {
    if [ ! -r "$ROOTMOUNT/etc/fstab" -a -r "$ROOTMOUNT/fstab.tmp" ]; then
        log_info "Creating file: $ROOTMOUNT/etc/fstab"
        mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
        chmod 644 "$ROOTMOUNT/etc/fstab"
    fi
    if [ -r "$ROOTMOUNT/etc/fstab" ]; then
        if [ -n "$SLACK_CD_FSTAB_ENTRY" ]; then
            fgrep "/cdrom" "$ROOTMOUNT/etc/fstab" >/dev/null 2>&1
            if [ $? -ne 0 ]; then
                pkgtool_mkdirs "$ROOTMOUNT/cdrom"
                log_info "Updating file: $ROOTMOUNT/etc/fstab"
                echo "$SLACK_CD_FSTAB_ENTRY" >>"$ROOTMOUNT/etc/fstab"
            fi
        fi
        fgrep "/proc" "$ROOTMOUNT/etc/fstab" >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_info "Updating file: $ROOTMOUNT/etc/fstab"
            echo "none        /proc        proc        defaults" >>"$ROOTMOUNT/etc/fstab"
            echo " " >>"$ROOTMOUNT/etc/fstab"
        fi
    fi
}

# Create /dev/cdrom for the configured CD-ROM device.
install_cdrom_link() {
    if [ -n "$CD_DEVICE" ]; then
        pkgtool_mkdirs "$ROOTMOUNT/dev"
        if [ ! -L "$ROOTMOUNT/dev/cdrom" -a ! -r "$ROOTMOUNT/dev/cdrom" ]; then
            log_info "Creating symlink: $ROOTMOUNT/dev/cdrom -> $CD_DEVICE"
            (
                cd "$ROOTMOUNT/dev" || exit 1
                ln -sf "$CD_DEVICE" cdrom
            )
        fi
    fi
}

# Fix known target permissions and compatibility symlinks.
fix_permissions() {
    log_info "Fixing permissions..."
    (
        cd "$ROOTMOUNT" || exit 1
        chmod 755 ./
    )
    if [ -d "$ROOTMOUNT/var" ]; then
        (
            cd "$ROOTMOUNT" || exit 1
            chmod 755 ./var
        )
    fi
    if [ -d "$ROOTMOUNT/usr/src/linux" ]; then
        chmod 755 "$ROOTMOUNT/usr/src/linux"
    fi
    if [ ! -d "$ROOTMOUNT/proc" ]; then
        pkgtool_mkdirs "$ROOTMOUNT/proc"
        chown root.root "$ROOTMOUNT/proc"
    fi
    if [ ! -L "$ROOTMOUNT/lib/cpp" ]; then
        log_info "Creating symlink: $ROOTMOUNT/lib/cpp -> /usr/lib/gcc-lib/i486-linux/*.*.*/cpp"
        (
            cd "$ROOTMOUNT/lib" || exit 1
            ln -sf /usr/lib/gcc-lib/i486-linux/*.*.*/cpp cpp
        )
    fi

    pkgtool_mkdirs "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucp"
    chown uucp.uucp "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucp"
    chmod 1777 "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucp"

    pkgtool_mkdirs "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucppublic"
    chown uucp.uucp "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucppublic"
    chmod 1777 "$ROOTMOUNT/$SLACK_SPOOL_DIR/uucppublic"

    chmod 1777 "$ROOTMOUNT/tmp"
    if [ ! -d "$ROOTMOUNT/$SLACK_SPOOL_DIR/mail" ]; then
        pkgtool_mkdirs "$ROOTMOUNT/$SLACK_SPOOL_DIR/mail"
        chmod 755 "$ROOTMOUNT/$SLACK_SPOOL_DIR"
        chown root.mail "$ROOTMOUNT/$SLACK_SPOOL_DIR/mail"
        chmod 775 "$ROOTMOUNT/$SLACK_SPOOL_DIR/mail"
    fi
}

# Link Slackware's localtime file to the selected timezone.
set_timezone() {
    if [ -n "$TIMEZONE" -a -d "$ROOTMOUNT/usr/lib/zoneinfo" ]; then
        log_info "Setting timezone to $TIMEZONE..."
        log_info "Creating symlink: $ROOTMOUNT/usr/lib/zoneinfo/localtime -> $TIMEZONE"
        (
            cd "$ROOTMOUNT/usr/lib/zoneinfo" || exit 1
            ln -sf "$TIMEZONE" localtime
        )
        move_setup_hook "$SLACK_TIMECONFIG"
    fi
}

# Write and install Slackware LILO configuration.
slackware_install_lilo() {
    if [ -x "$ROOTMOUNT/sbin/lilo" ]; then
        log_info "Installing lilo..."
        if [ -r "$ROOTMOUNT/boot/vmlinuz" ]; then
            LILO_IMAGE=/boot/vmlinuz
        else
            LILO_IMAGE=/vmlinuz
        fi
        BOOTDEV=$(echo "$ROOTDEV" | sed 's/[0-9][0-9]*$//')
        if [ "$BOOTDEV" = "$ROOTDEV" ]; then
            BOOTDEV=/dev/hda
        fi
        log_info "LILO configuration:"
        log_info "  BOOTDEV=$BOOTDEV"
        log_info "  ROOTDEV=$ROOTDEV"
        log_info "  LILO_IMAGE=$LILO_IMAGE"
        if [ -r "$ROOTMOUNT/etc/lilo.conf" ]; then
            log_info "Creating backup file: $ROOTMOUNT/etc/lilo.conf.bak"
            mv "$ROOTMOUNT/etc/lilo.conf" "$ROOTMOUNT/etc/lilo.conf.bak"
        fi
        log_info "Creating file: $ROOTMOUNT/etc/lilo.conf"
        cat >"$ROOTMOUNT/etc/lilo.conf" <<EOF
# LILO configuration file
# generated by autoinst
#
# Start LILO global section
boot = $BOOTDEV
#compact        # faster, but won't work on all systems.
# delay = 5
vga = normal    # force sane state
ramdisk = 0     # paranoia setting
# End LILO global section
# Linux bootable partition config begins
image = $LILO_IMAGE
  root = $ROOTDEV
  label = Linux
  read-only
# Linux bootable partition config ends
EOF
        chmod 644 "$ROOTMOUNT/etc/lilo.conf"
        if [ -x "$ROOTMOUNT/usr/lib/setup/bin/lilo" ]; then
            # Slackware ELF distributions need the a.out lilo from setup.
            log_info "Using setup LILO binary for Slackware ELF distribution"
            "$ROOTMOUNT/usr/lib/setup/bin/lilo" -r "$ROOTMOUNT" -m /boot/map -C /etc/lilo.conf
        elif [ -x "$ROOTMOUNT/sbin/lilo" ]; then
            log_info "Using installed LILO binary"
            "$ROOTMOUNT/sbin/lilo" -r "$ROOTMOUNT" -m /boot/map -C /etc/lilo.conf
        else
            log_warn "Could not find lilo binary. System may be unbootable!"
        fi
        move_setup_hook "$SLACK_LILOCONFIG"
    fi
}

# Install the first-boot autoconf hook through rc.local.
install_autoconf_hook() {
    pkgtool_mkdirs "$ROOTMOUNT/etc/rc.d"
    if [ ! -f "$ROOTMOUNT/etc/rc.d/rc.local" ]; then
        log_info "Creating file: $ROOTMOUNT/etc/rc.d/rc.local"
        touch "$ROOTMOUNT/etc/rc.d/rc.local"
        chmod 644 "$ROOTMOUNT/etc/rc.d/rc.local"
    fi
    log_info "Creating file: $ROOTMOUNT/autoconf.sh"
    cp "$INSTMOUNT/autoinst.d/autoconf.sh" "$ROOTMOUNT/autoconf.sh"
    chmod +x "$ROOTMOUNT/autoconf.sh"
    log_info "Updating file: $ROOTMOUNT/etc/rc.d/rc.local"
    echo "if [ -x /autoconf.sh ]; then" >>"$ROOTMOUNT/etc/rc.d/rc.local"
    echo "  /autoconf.sh" >>"$ROOTMOUNT/etc/rc.d/rc.local"
    echo "fi" >>"$ROOTMOUNT/etc/rc.d/rc.local"
}

# Run the full Slackware pkgtool install sequence.
slackware_install_with_pkgtool() {
    install_pkgtool_sets
    log_div
    write_rootdev
    install_fstab
    install_cdrom_link
    fix_permissions
    set_timezone
    slackware_install_lilo
    install_autoconf_hook
}
