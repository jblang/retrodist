# Fill unset serial-console variables with defaults.
tty_set_defaults() {
    TTY_DEV=${TTY_DEV:-ttyS0}
    TTY_BAUD=${TTY_BAUD:-9600}
    TTY_RUNLEVELS=${TTY_RUNLEVELS:-123456}
    # Early Slackware/SLS may spell serial devices as ttysN instead of ttySN.
    case "$TTY_DEV" in
    ttyS[0-9]*)
        TTY_DEV_ALT=ttys${TTY_DEV#ttyS}
        TTY_ID=${TTY_ID:-s${TTY_DEV#ttyS}}
        log_debug "Using alternate serial device spelling: $TTY_DEV_ALT"
        ;;
    ttys[0-9]*)
        TTY_DEV_ALT=ttyS${TTY_DEV#ttys}
        TTY_ID=${TTY_ID:-s${TTY_DEV#ttys}}
        log_debug "Using alternate serial device spelling: $TTY_DEV_ALT"
        ;;
    *)
        TTY_DEV_ALT=
        TTY_ID=${TTY_ID:-s0}
        ;;
    esac
    log_info "TTY configuration:"
    log_info "  TTY_DEV=$TTY_DEV"
    log_info "  TTY_DEV_ALT=$TTY_DEV_ALT"
    log_info "  TTY_ID=$TTY_ID"
    log_info "  TTY_BAUD=$TTY_BAUD"
    log_info "  TTY_RUNLEVELS=$TTY_RUNLEVELS"
}

# Populate target paths for serial-console configuration files.
tty_detect_paths() {
    TTY_INITTAB="$ETCPATH/inittab"
    TTY_INITTAB_NEW="$ETCPATH/inittab.new"
    TTY_LOGIN_DEFS="$ETCPATH/login.defs"
    TTY_LOGIN_DEFS_NEW="$ETCPATH/login.defs.new"
    TTY_SECURETTY="$ETCPATH/securetty"

    if [ ! -f "$TTY_INITTAB" ]; then
        log_warn "No inittab found at $TTY_INITTAB; skipping serial console configuration"
        return 1
    fi
    log_debug "TTY paths:"
    log_debug "  inittab=$TTY_INITTAB"
    log_debug "  login_defs=$TTY_LOGIN_DEFS"
    log_debug "  securetty=$TTY_SECURETTY"
}

# Copy a file to a .orig backup before replacing it, preserving the first copy.
tty_backup_orig() {
    if [ -f "$1" ] && [ ! -f "$1.orig" ]; then
        log_debug "Creating backup file: $1.orig"
        cp "$1" "$1.orig"
    fi
}

# Emit the first matching active getty line for a device.
tty_find_active_line_for_device() {
    sed -n "/^[^#].*:respawn:.* $1\\([ 	].*\\)\{0,1\}\$/p" "$TTY_INITTAB" |
        sed -n '1p'
}

# Find the first commented getty line for ttyS0, ttyS1, ttys0, or ttys1.
tty_find_serial_getty_line() {
    # Look for any commented line with getty or agetty (not uugetty) for serial ports 0 or 1
    # Match both ttyS and ttys with either case
    # Pattern matches both "getty 9600 ttyS0" and "getty ttyS0 9600" formats
    # Use grep to exclude uugetty, then take first match
    grep '^#.*:.*:respawn:.*getty.*tty[Ss][01]' "$TTY_INITTAB" | grep -v 'uugetty' | head -1
}

# Set TTY_STOCK_LINE to a serial getty line, or fail when one is already active.
tty_find_getty_line() {
    # Avoid shell read loops here; Slackware 3.0's /bin/sh can segfault in read.
    # shellcheck disable=SC2006
    TTY_ACTIVE_LINE=$(tty_find_active_line_for_device "$TTY_DEV")
    if [ -z "$TTY_ACTIVE_LINE" ] && [ -n "$TTY_DEV_ALT" ]; then
        # shellcheck disable=SC2006
        TTY_ACTIVE_LINE=$(tty_find_active_line_for_device "$TTY_DEV_ALT")
    fi
    if [ -n "$TTY_ACTIVE_LINE" ]; then
        return 1
    fi

    # Find any serial getty line for ports 0 or 1
    # shellcheck disable=SC2006
    TTY_STOCK_LINE=$(tty_find_serial_getty_line)
    if [ -n "$TTY_STOCK_LINE" ]; then
        log_debug "Found serial getty line: $TTY_STOCK_LINE"
        # Determine which device to use based on what we want
        TTY_STOCK_DEV=$TTY_DEV
    else
        log_debug "No serial getty line found in inittab"
    fi
}

# Uncomment and adapt a serial getty line for the target device.
tty_write_inittab() {
    if [ -n "$TTY_STOCK_LINE" ]; then
        log_info "Enabling serial getty entry for $TTY_STOCK_DEV"
        # Uncomment the line
        TTY_UNCOMMENTED=${TTY_STOCK_LINE#\#}
        # Extract the getty command part (everything after the third colon)
        # shellcheck disable=SC2006
        TTY_GETTY_CMD=$(echo "$TTY_UNCOMMENTED" | sed 's/^[^:]*:[^:]*:[^:]*://')
        # Replace any ttyS[01] or ttys[01] with our target device in the command
        # shellcheck disable=SC2006
        TTY_GETTY_CMD=$(echo "$TTY_GETTY_CMD" | sed "s/tty[Ss][01]/$TTY_STOCK_DEV/g")
        # Build new line with our runlevels (12345) and the adapted getty command
        TTY_NEW_LINE="$TTY_ID:$TTY_RUNLEVELS:respawn:$TTY_GETTY_CMD"
        log_debug "Generated line: $TTY_NEW_LINE"
        # Append the new line after the stock line
        # shellcheck disable=SC2006
        TTY_ESCAPED_STOCK=$(echo "$TTY_STOCK_LINE" | sed 's/[\/&]/\\&/g')
        sed "/^$TTY_ESCAPED_STOCK\$/a\\
$TTY_NEW_LINE\\
" "$TTY_INITTAB" >"$TTY_INITTAB_NEW"
        mv "$TTY_INITTAB_NEW" "$TTY_INITTAB"
    else
        log_warn "No serial getty line found; leaving inittab unchanged"
        return 1
    fi
}

# Run one tty config step without letting its failure stop later autoconf steps.
tty_run_step() {
    if "$1"; then
        :
    else
        log_warn "$1 failed for $TTY_DEV; skipping remaining tty configuration"
        return 1
    fi
}

# Add or enable the serial getty entry in /etc/inittab.
tty_config_inittab() {
    if tty_find_getty_line; then
        :
    else
        log_warn "Active getty line already exists for $TTY_DEV; leaving inittab unchanged"
        return 0
    fi

    tty_backup_orig "$TTY_INITTAB"
    tty_write_inittab
}

# Comment out CONSOLE in login.defs so securetty controls root login devices.
tty_config_login_defs() {
    if [ -f "$TTY_LOGIN_DEFS" ]; then
        tty_backup_orig "$TTY_LOGIN_DEFS"
        log_info "Creating file: $TTY_LOGIN_DEFS"
        # Work from the current file so reruns preserve unrelated local edits.
        sed 's/^CONSOLE/#CONSOLE/' "$TTY_LOGIN_DEFS" >"$TTY_LOGIN_DEFS_NEW"
        mv "$TTY_LOGIN_DEFS_NEW" "$TTY_LOGIN_DEFS"
    else
        log_debug "No login.defs found at $TTY_LOGIN_DEFS"
    fi
}

# Append the configured serial device to securetty when it is not already present.
tty_config_securetty() {
    tty_backup_orig "$TTY_SECURETTY"
    if [ -f "$TTY_SECURETTY" ]; then
        if grep "^$TTY_DEV\$" "$TTY_SECURETTY" >/dev/null 2>&1; then
            log_info "$TTY_DEV already present in $TTY_SECURETTY"
            return 0
        fi
    fi
    log_info "Updating file: $TTY_SECURETTY"
    echo "$TTY_DEV" >>"$TTY_SECURETTY"
}

# Entry point for enabling the target serial login console.
_tty_config() {
    log_div
    tty_set_defaults
    log_info "Configuring serial console on $TTY_DEV..."

    if tty_detect_paths; then
        tty_run_step tty_config_inittab &&
            tty_run_step tty_config_login_defs &&
            tty_run_step tty_config_securetty
    fi

    return 0
}
