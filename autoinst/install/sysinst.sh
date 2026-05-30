_slackware_sysinstall() {
    # installer for SLS sysinstall-based versions
    INSTSRC=${SYSINSTALL_INSTSRC:-$INSTMOUNT/install}

    # mini - Install the base Slackware Linux disks (series A)
    # X11 - Install the Slackware series A + Slackware or SLS series X (X11)
    # tex - Install the Slackware series A + X (X Windows) + T (TeX support)
    # everything - Install everything (90 Meg)
    if [ -n "$SYSINSTALL_MODE" ]; then
        INSTTYPE=$SYSINSTALL_MODE
    elif [ -d "$INSTSRC/x1" ]; then
        if [ -d "$INSTSRC/t1" ]; then
            INSTTYPE=tex
        else
            INSTTYPE=X11
        fi
    else
        INSTTYPE=mini
    fi

    echo "## performing $INSTTYPE install; please wait..."

    mkdir -p "$ROOTMOUNT/install/installed"
    mkdir -p "$ROOTMOUNT/install/disks"
    mkdir -p "$ROOTMOUNT/install/scripts"
    mkdir -p "$ROOTMOUNT/install/catalog"
    sysinstall -instsrc "$INSTSRC" -instroot "$ROOTMOUNT" -"$INSTTYPE"
    mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"

    echo '## configuring system...'

    # normal VGA mode
    VGAMODE=${VGAMODE:--1}

    # Configure kernel with boot device and vga mode
    echo "FLOPPYA $INSTDEV" >> "$ROOTMOUNT/etc/hwconfig"
    echo "ROOTDEV $ROOTDEV" >> "$ROOTMOUNT/etc/hwconfig"
    echo "VGAMODE $VGAMODE" >> "$ROOTMOUNT/etc/hwconfig"

    # Skip modem/mouse config and install Linux-only LILO.
    if [ "$SYSSETUP_PROFILE" = "sls103" ]; then
      ( echo n; echo n; echo; echo; echo ) | ( cd "$ROOTMOUNT"; etc/syssetup -instroot "$ROOTMOUNT" -install )
    else
      ( echo n; echo n; echo 2 ) | ( cd "$ROOTMOUNT"; etc/syssetup -instroot "$ROOTMOUNT" -install )
    fi

    # set up autoconf script to run on first boot
    cp "$INSTMOUNT/autoinst.d/autoconf.sh" "$ROOTMOUNT/autoconf.sh"
    chmod +x "$ROOTMOUNT/autoconf.sh"
    echo "if [ -x /autoconf.sh ]; then" >> "$ROOTMOUNT/etc/rc.local"
    echo "  /autoconf.sh" >> "$ROOTMOUNT/etc/rc.local"
    echo "fi" >> "$ROOTMOUNT/etc/rc.local"
}

sls_install_pkg() {
    PKGFILE=$1
    PKGNAME=`basename "$PKGFILE"`
    PKGNAME=`echo "$PKGNAME" | sed 's/\.[Tt][Pp][Zz]$//' | sed 's/\.[Tt][Aa][Zz]$//' | sed 's/\.[Tt][Aa][Rr]$//'`
    sysinstall -instroot "$ROOTMOUNT" -install "$PKGFILE"
}

sls_install_diskdir() {
    DISKDIR=$1
    for PKGNAME in `ls "$DISKDIR"`; do
        case "$PKGNAME" in
            *.taz | *.TAZ | *.tpz | *.TPZ | *.tar | *.TAR)
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
        if [ ! -d "$DISKDIR" ]; then
            continue
        fi
        sls_install_diskdir "$DISKDIR"
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

_sls_sysinstall() {
    INSTTYPE=`sls_detect_install_mode`

    echo "## performing $INSTTYPE install; please wait..."

    mkdir -p "$ROOTMOUNT/install/installed"
    mkdir -p "$ROOTMOUNT/install/scripts"

    sls_install_mounted_disk
    sls_install_series a
    if [ "$INSTTYPE" = "base" -o "$INSTTYPE" = "all" ]; then
        sls_install_series b
        sls_install_series c
    fi
    if [ "$INSTTYPE" = "all" ]; then
        sls_install_series x
    fi

    if [ -f "$ROOTMOUNT/fstab.tmp" ]; then
        mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
    fi
}