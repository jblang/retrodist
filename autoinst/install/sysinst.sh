# shellcheck shell=sh
# Create target directories for sysinstall-based installers.
sysinstall_mkdirs() {
    for DIR in "$@"; do
        log_debug "Creating directory: $ROOTMOUNT/$DIR"
        mkdir -p "$ROOTMOUNT/$DIR"
    done
}

# Move the generated fstab into the installed system.
sysinstall_finish_fstab() {
    if [ -f "$ROOTMOUNT/fstab.tmp" ]; then
        log_info "Creating file: $ROOTMOUNT/etc/fstab"
        mv "$ROOTMOUNT/fstab.tmp" "$ROOTMOUNT/etc/fstab"
    else
        log_debug "No temporary fstab found at $ROOTMOUNT/fstab.tmp"
    fi
}

# Install one SLS package with sysinstall.
sls_install_pkg() {
    sysinstall -instroot "$ROOTMOUNT" -install "$1"
}

# Install every SLS package in one disk directory.
sls_install_diskdir() {
    DISKDIR=$1
    for PKGNAME in $(ls "$DISKDIR"); do
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

# Install packages from a mounted SLS /user disk.
sls_install_mounted_disk() {
    if [ -d /user ]; then
        log_info "Detected mounted SLS disk at /user"
        sls_install_diskdir /user
    else
        log_debug "No mounted SLS disk at /user"
    fi
}

# Install one selected SLS package series.
sls_install_series() {
    SERIES=$1
    if [ "$SERIES" = "a" ]; then
        DISKPATTERN="$INSTMOUNT/packages/a[2-9] $INSTMOUNT/packages/a[1-9][0-9]"
    else
        DISKPATTERN="$INSTMOUNT/packages/${SERIES}[1-9] $INSTMOUNT/packages/${SERIES}[1-9][0-9]"
    fi
    log_info "Installing SLS series $SERIES"

    for DISKDIR in $DISKPATTERN; do
        if [ -d "$DISKDIR" ]; then
            sls_install_diskdir "$DISKDIR"
        fi
    done
}

# Select SLS install mode from config or staged media.
sls_detect_install_mode() {
    if [ -n "$SLS_INSTALL_MODE" ]; then
        log_info "Using configured SLS_INSTALL_MODE=$SLS_INSTALL_MODE"
        echo "$SLS_INSTALL_MODE"
    elif [ -d "$INSTMOUNT/packages/x1" -o -d "$INSTMOUNT/packages/x2" ]; then
        log_info "Detected SLS install mode: all"
        echo all
    elif [ -d "$INSTMOUNT/packages/b1" -o -d "$INSTMOUNT/packages/c1" ]; then
        log_info "Detected SLS install mode: base"
        echo base
    else
        log_info "Detected SLS install mode: mini"
        echo mini
    fi
}

# Install the SLS series required by the selected mode.
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

# Install SLS using sysinstall.
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
