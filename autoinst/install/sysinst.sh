sysinstall_mkdirs() {
    for DIR in "$@"; do
        log_debug "Creating directory: $ROOTMOUNT/$DIR"
        mkdir -p "$ROOTMOUNT/$DIR"
    done
}

sysinstall_finish_fstab() {
    if [ -f "$ROOTMOUNT/fstab.tmp" ]; then
        log_info "Creating file: $ROOTMOUNT/etc/fstab"
        mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
    else
        log_debug "No temporary fstab found at $ROOTMOUNT/fstab.tmp"
    fi
}

sysinstall_install_autoconf_hook() {
    log_info "Creating file: $ROOTMOUNT/autoconf.sh"
    cp "$INSTMOUNT/autoinst.d/autoconf.sh" "$ROOTMOUNT/autoconf.sh"
    chmod +x "$ROOTMOUNT/autoconf.sh"
    log_info "Updating file: $ROOTMOUNT/etc/rc.local"
    echo "if [ -x /autoconf.sh ]; then" >> "$ROOTMOUNT/etc/rc.local"
    echo "  /autoconf.sh" >> "$ROOTMOUNT/etc/rc.local"
    echo "fi" >> "$ROOTMOUNT/etc/rc.local"
}

slackware_detect_sysinstall_mode() {
    if [ -n "$SYSINSTALL_MODE" ]; then
        log_info "Using configured SYSINSTALL_MODE=$SYSINSTALL_MODE"
        echo "$SYSINSTALL_MODE"
    elif [ -d "$INSTSRC/x1" ]; then
        if [ -d "$INSTSRC/t1" ]; then
            log_info "Detected Slackware sysinstall mode: tex"
            echo tex
        else
            log_info "Detected Slackware sysinstall mode: X11"
            echo X11
        fi
    else
        log_info "Detected Slackware sysinstall mode: mini"
        echo mini
    fi
}

slackware_write_hwconfig() {
    VGAMODE=${VGAMODE:--1}
    log_info "Hardware configuration:"
    log_info "  INSTDEV=$INSTDEV"
    log_info "  ROOTDEV=$ROOTDEV"
    log_info "  VGAMODE=$VGAMODE"
    log_info "Updating file: $ROOTMOUNT/etc/hwconfig"
    echo "FLOPPYA $INSTDEV" >> "$ROOTMOUNT/etc/hwconfig"
    echo "ROOTDEV $ROOTDEV" >> "$ROOTMOUNT/etc/hwconfig"
    echo "VGAMODE $VGAMODE" >> "$ROOTMOUNT/etc/hwconfig"
}

slackware_run_syssetup() {
    # Skip modem/mouse config and install Linux-only LILO.
    if [ "$SYSSETUP_PROFILE" = "sls103" ]; then
        log_info "Running syssetup with sls103 profile"
        ( echo n; echo n; echo; echo; echo ) | ( cd "$ROOTMOUNT"; etc/syssetup -instroot "$ROOTMOUNT" -install )
    else
        log_info "Running syssetup"
        ( echo n; echo n; echo 2 ) | ( cd "$ROOTMOUNT"; etc/syssetup -instroot "$ROOTMOUNT" -install )
    fi
}

_slackware_sysinstall() {
    # installer for SLS sysinstall-based Slackware versions
    log_div
    log_info "Installing Slackware with sysinstall"
    INSTSRC=${SYSINSTALL_INSTSRC:-$INSTMOUNT/install}
    log_info "Slackware sysinstall configuration:"
    log_info "  INSTSRC=$INSTSRC"
    log_info "  ROOTMOUNT=$ROOTMOUNT"
    INSTTYPE=$(slackware_detect_sysinstall_mode)

    log_info "Performing $INSTTYPE install; please wait..."

    sysinstall_mkdirs \
        install/installed \
        install/disks \
        install/scripts \
        install/catalog

    log_debug "sysinstall command: sysinstall -instsrc $INSTSRC -instroot $ROOTMOUNT -$INSTTYPE"
    sysinstall -instsrc "$INSTSRC" -instroot "$ROOTMOUNT" -"$INSTTYPE"
    sysinstall_finish_fstab

    log_info "Configuring system..."
    slackware_write_hwconfig
    slackware_run_syssetup
    sysinstall_install_autoconf_hook
}

sls_install_pkg() {
    sysinstall -instroot "$ROOTMOUNT" -install "$1"
}

sls_install_diskdir() {
    DISKDIR=$1
    for PKGNAME in `ls "$DISKDIR"`; do
        case "$PKGNAME" in
            *.taz | *.TAZ | *.tpz | *.TPZ | *.tar | *.TAR )
                PKGFILE="$DISKDIR/$PKGNAME"
                if [ -f "$PKGFILE" ]; then
                    sls_install_pkg "$PKGFILE"
                fi
                ;;
        esac
    done
}

sls_install_mounted_disk() {
    if [ -d /user ]; then
        log_info "Detected mounted SLS disk at /user"
        sls_install_diskdir /user
    else
        log_debug "No mounted SLS disk at /user"
    fi
}

sls_install_series() {
    SERIES=$1
    if [ "$SERIES" = "a" ]; then
        DISKPATTERN="$INSTMOUNT/install/a[2-9] $INSTMOUNT/install/a[1-9][0-9]"
    else
        DISKPATTERN="$INSTMOUNT/install/$SERIES[1-9] $INSTMOUNT/install/$SERIES[1-9][0-9]"
    fi
    log_info "Installing SLS series $SERIES"

    for DISKDIR in $DISKPATTERN; do
        if [ -d "$DISKDIR" ]; then
            sls_install_diskdir "$DISKDIR"
        fi
    done
}

sls_detect_install_mode() {
    if [ -n "$SLS_INSTALL_MODE" ]; then
        log_info "Using configured SLS_INSTALL_MODE=$SLS_INSTALL_MODE"
        echo "$SLS_INSTALL_MODE"
    elif [ -d "$INSTMOUNT/install/x1" -o -d "$INSTMOUNT/install/x2" ]; then
        log_info "Detected SLS install mode: all"
        echo all
    elif [ -d "$INSTMOUNT/install/b1" -o -d "$INSTMOUNT/install/c1" ]; then
        log_info "Detected SLS install mode: base"
        echo base
    else
        log_info "Detected SLS install mode: mini"
        echo mini
    fi
}

sls_install_selected_series() {
    sls_install_series a

    if [ "$INSTTYPE" = "base" -o "$INSTTYPE" = "all" ]; then
        log_info "Including SLS base development series"
        sls_install_series b
        sls_install_series c
    else
        log_info "Skipping SLS b/c series for install mode $INSTTYPE"
    fi

    if [ "$INSTTYPE" = "all" ]; then
        log_info "Including SLS X series"
        sls_install_series x
    else
        log_info "Skipping SLS X series for install mode $INSTTYPE"
    fi
}

_sls_sysinstall() {
    log_div
    log_info "Installing SLS with sysinstall"
    INSTTYPE=$(sls_detect_install_mode)

    log_info "Performing $INSTTYPE install; please wait..."

    sysinstall_mkdirs \
        install/installed \
        install/scripts

    sls_install_mounted_disk
    sls_install_selected_series
    sysinstall_finish_fstab
}
