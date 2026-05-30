sysinstall_mkdirs() {
    for DIR in "$@"; do
        mkdir -p "$ROOTMOUNT/$DIR"
    done
}

sysinstall_finish_fstab() {
    if [ -f "$ROOTMOUNT/fstab.tmp" ]; then
        mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
    fi
}

sysinstall_install_autoconf_hook() {
    cp "$INSTMOUNT/autoinst.d/autoconf.sh" "$ROOTMOUNT/autoconf.sh"
    chmod +x "$ROOTMOUNT/autoconf.sh"
    echo "if [ -x /autoconf.sh ]; then" >> "$ROOTMOUNT/etc/rc.local"
    echo "  /autoconf.sh" >> "$ROOTMOUNT/etc/rc.local"
    echo "fi" >> "$ROOTMOUNT/etc/rc.local"
}

slackware_detect_sysinstall_mode() {
    if [ -n "$SYSINSTALL_MODE" ]; then
        echo "$SYSINSTALL_MODE"
    elif [ -d "$INSTSRC/x1" ]; then
        if [ -d "$INSTSRC/t1" ]; then
            echo tex
        else
            echo X11
        fi
    else
        echo mini
    fi
}

slackware_write_hwconfig() {
    VGAMODE=${VGAMODE:--1}
    echo "FLOPPYA $INSTDEV" >> "$ROOTMOUNT/etc/hwconfig"
    echo "ROOTDEV $ROOTDEV" >> "$ROOTMOUNT/etc/hwconfig"
    echo "VGAMODE $VGAMODE" >> "$ROOTMOUNT/etc/hwconfig"
}

slackware_run_syssetup() {
    # Skip modem/mouse config and install Linux-only LILO.
    if [ "$SYSSETUP_PROFILE" = "sls103" ]; then
        ( echo n; echo n; echo; echo; echo ) | ( cd "$ROOTMOUNT"; etc/syssetup -instroot "$ROOTMOUNT" -install )
    else
        ( echo n; echo n; echo 2 ) | ( cd "$ROOTMOUNT"; etc/syssetup -instroot "$ROOTMOUNT" -install )
    fi
}

_slackware_sysinstall() {
    # installer for SLS sysinstall-based Slackware versions
    INSTSRC=${SYSINSTALL_INSTSRC:-$INSTMOUNT/install}
    INSTTYPE=$(slackware_detect_sysinstall_mode)

    echo "## performing $INSTTYPE install; please wait..."

    sysinstall_mkdirs \
        install/installed \
        install/disks \
        install/scripts \
        install/catalog

    sysinstall -instsrc "$INSTSRC" -instroot "$ROOTMOUNT" -"$INSTTYPE"
    sysinstall_finish_fstab

    echo "## configuring system..."
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
        sls_install_diskdir /user
    fi
}

sls_install_series() {
    SERIES=$1
    if [ "$SERIES" = "a" ]; then
        DISKPATTERN="$INSTMOUNT/install/a[2-9] $INSTMOUNT/install/a[1-9][0-9]"
    else
        DISKPATTERN="$INSTMOUNT/install/$SERIES[1-9] $INSTMOUNT/install/$SERIES[1-9][0-9]"
    fi

    for DISKDIR in $DISKPATTERN; do
        if [ -d "$DISKDIR" ]; then
            sls_install_diskdir "$DISKDIR"
        fi
    done
}

sls_detect_install_mode() {
    if [ -n "$SLS_INSTALL_MODE" ]; then
        echo "$SLS_INSTALL_MODE"
    elif [ -d "$INSTMOUNT/install/x1" -o -d "$INSTMOUNT/install/x2" ]; then
        echo all
    elif [ -d "$INSTMOUNT/install/b1" -o -d "$INSTMOUNT/install/c1" ]; then
        echo base
    else
        echo mini
    fi
}

sls_install_selected_series() {
    sls_install_series a

    if [ "$INSTTYPE" = "base" -o "$INSTTYPE" = "all" ]; then
        sls_install_series b
        sls_install_series c
    fi

    if [ "$INSTTYPE" = "all" ]; then
        sls_install_series x
    fi
}

_sls_sysinstall() {
    INSTTYPE=$(sls_detect_install_mode)

    echo "## performing $INSTTYPE install; please wait..."

    sysinstall_mkdirs \
        install/installed \
        install/scripts

    sls_install_mounted_disk
    sls_install_selected_series
    sysinstall_finish_fstab
}
