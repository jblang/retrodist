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

sls_sysinstall() {
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

make_boot_floppy() {
    BOOTFLOPPYDEV=${BOOTFLOPPYDEV:-/dev/fd0}
    BOOTKERNEL=${BOOTKERNEL:-$ROOTMOUNT/Image}
    echo "### Creating boot floppy on $BOOTFLOPPYDEV..."

    if [ ! -f "$BOOTKERNEL" ]; then
        echo "Installed kernel $BOOTKERNEL not found."
        return 1
    fi
    
    umount /user >/dev/null 2>&1
    echo "Reattach boot.img and press ENTER."
    read line

    dd if="$BOOTKERNEL" of="$BOOTFLOPPYDEV"
    if [ $? -ne 0 ]; then
        echo "Boot floppy write failed."
        return 1
    fi

    rootdev "$BOOTFLOPPYDEV" "$ROOTDEV"
    if [ $? -ne 0 ]; then
        echo "rootdev failed for $BOOTFLOPPYDEV."
        return 1
    fi

    return 0
}
