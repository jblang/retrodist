# Fill unset serial-console variables with defaults.
tty_set_defaults() {
    TTY_DEV=${TTY_DEV:-ttyS0}
    TTY_BAUD=${TTY_BAUD:-9600}
    TTY_RUNLEVELS=${TTY_RUNLEVELS:-123456}
    TTY_ETCPATH=${TTY_ETCPATH:-/etc}

    # Early Slackware/SLS may spell serial devices as ttysN instead of ttySN.
    case "$TTY_DEV" in
        ttyS[0-9]*)
            TTY_DEV_ALT=ttys${TTY_DEV#ttyS}
            TTY_ID=${TTY_ID:-s${TTY_DEV#ttyS}}
            ;;
        ttys[0-9]*)
            TTY_DEV_ALT=ttyS${TTY_DEV#ttys}
            TTY_ID=${TTY_ID:-s${TTY_DEV#ttys}}
            ;;
        *)
            TTY_DEV_ALT=
            TTY_ID=${TTY_ID:-s0}
            ;;
    esac
}

# Populate target paths for serial-console configuration files.
tty_detect_paths() {
    TTY_INITTAB="$TTY_ETCPATH/inittab"
    TTY_INITTAB_NEW="$TTY_ETCPATH/inittab.new"
    TTY_LOGIN_DEFS="$TTY_ETCPATH/login.defs"
    TTY_LOGIN_DEFS_NEW="$TTY_ETCPATH/login.defs.new"
    TTY_SECURETTY="$TTY_ETCPATH/securetty"

    if [ ! -f "$TTY_INITTAB" ]; then
        return 1
    fi
}

# Copy a file to a .orig backup before replacing it, preserving the first copy.
tty_backup_orig() {
    if [ -f "$1" ] && [ ! -f "$1.orig" ]; then
        cp "$1" "$1.orig"
    fi
}

# Emit the first matching active getty line for a device.
tty_find_active_line_for_device() {
    sed -n "/^[^#].*:respawn:.* $1\\([ 	].*\\)\{0,1\}\$/p" "$TTY_INITTAB" |
        sed -n '1p'
}

# Emit the first matching stock getty comment for a device.
tty_find_stock_line_for_device() {
    sed -n "/^#s[0-9]:[0-9][0-9]*:respawn:.* $1\\([ 	].*\\)\{0,1\}\$/p" "$TTY_INITTAB" |
        sed -n '1p'
}

# Set TTY_STOCK_LINE to the first stock getty line, or fail when one is active.
tty_find_getty_line() {
    # Avoid shell read loops here; Slackware 3.0's /bin/sh can segfault in read.
    # shellcheck disable=SC2006
    TTY_ACTIVE_LINE=`tty_find_active_line_for_device "$TTY_DEV"`
    if [ -z "$TTY_ACTIVE_LINE" ] && [ -n "$TTY_DEV_ALT" ]; then
        # shellcheck disable=SC2006
        TTY_ACTIVE_LINE=`tty_find_active_line_for_device "$TTY_DEV_ALT"`
    fi
    if [ -n "$TTY_ACTIVE_LINE" ]; then
        return 1
    fi

    TTY_STOCK_DEV=$TTY_DEV
    # shellcheck disable=SC2006
    TTY_STOCK_LINE=`tty_find_stock_line_for_device "$TTY_DEV"`
    if [ -z "$TTY_STOCK_LINE" ] && [ -n "$TTY_DEV_ALT" ]; then
        TTY_STOCK_DEV=$TTY_DEV_ALT
        # shellcheck disable=SC2006
        TTY_STOCK_LINE=`tty_find_stock_line_for_device "$TTY_DEV_ALT"`
    fi
}

# Detect the preferred available getty binary.
tty_detect_getty() {
    for TTY_GETTY in /sbin/agetty /sbin/getty /etc/getty; do
        if [ -x "$TTY_GETTY" ]; then
            return 0
        fi
    done

    echo "Warning: no getty binary found for $TTY_DEV; leaving inittab unchanged" >&2
    return 1
}

# Emit the getty command used by the inittab serial entry.
tty_build_getty_command() {
    if tty_detect_getty; then
        :
    else
        return 0
    fi

    case "$TTY_GETTY" in
        agetty|*/agetty)
            echo "$TTY_GETTY $TTY_BAUD $TTY_DEV ${TTY_TERM:-vt100}"
            ;;
        *)
            echo "$TTY_GETTY $TTY_DEV $TTY_BAUD"
            ;;
    esac
}

# Emit the full inittab line used for the configured getty.
tty_build_inittab_line() {
    if [ -n "$TTY_STOCK_LINE" ]; then
        # Reuse the stock id/runlevels/action, but build the command separately.
        TTY_STOCK_ACTIVE=${TTY_STOCK_LINE#\#}
        # shellcheck disable=SC2006
        TTY_STOCK_PREFIX=`echo "$TTY_STOCK_ACTIVE" | sed 's/:[^:]*$//'`
    else
        TTY_STOCK_PREFIX="$TTY_ID:$TTY_RUNLEVELS:respawn"
    fi

    echo "$TTY_STOCK_PREFIX:$TTY_GETTY_COMMAND"
}

# Insert after a stock commented serial line or append a new serial getty entry.
tty_write_inittab() {
    if [ -n "$TTY_STOCK_LINE" ]; then
        # Rewrite the current file, not .orig; .orig is only the first-run backup.
        # Avoid shell read loops here; Slackware 3.0's /bin/sh can segfault in read.
        sed -n "/^#s[0-9]:[0-9][0-9]*:respawn:.* $TTY_STOCK_DEV\\([ 	].*\\)\{0,1\}\$/{
p
a\\
$TTY_INITTAB_LINE
:copy
n
p
b copy
}
p" "$TTY_INITTAB" > "$TTY_INITTAB_NEW"
        mv "$TTY_INITTAB_NEW" "$TTY_INITTAB"
    else
        echo "$TTY_INITTAB_LINE" >> "$TTY_INITTAB"
    fi
}

# Run one tty config step without letting its failure stop later autoconf steps.
tty_run_step() {
    if "$1"; then
        :
    else
        echo "Warning: $1 failed for $TTY_DEV; skipping remaining tty configuration" >&2
        return 1
    fi
}

# Add or enable the serial getty entry in /etc/inittab.
tty_config_inittab() {
    if tty_find_getty_line; then
        :
    else
        echo "Warning: active getty line already exists for $TTY_DEV; leaving inittab unchanged" >&2
        return 0
    fi

    # shellcheck disable=SC2006
    TTY_GETTY_COMMAND=`tty_build_getty_command`
    tty_backup_orig "$TTY_INITTAB"
    if [ -z "$TTY_GETTY_COMMAND" ]; then
        return 0
    fi
    # shellcheck disable=SC2006
    TTY_INITTAB_LINE=`tty_build_inittab_line`

    tty_write_inittab
}

# Comment out CONSOLE in login.defs so securetty controls root login devices.
tty_config_login_defs() {
    if [ -f "$TTY_LOGIN_DEFS" ]; then
        tty_backup_orig "$TTY_LOGIN_DEFS"
        # Work from the current file so reruns preserve unrelated local edits.
        sed 's/^CONSOLE/#CONSOLE/' "$TTY_LOGIN_DEFS" > "$TTY_LOGIN_DEFS_NEW"
        mv "$TTY_LOGIN_DEFS_NEW" "$TTY_LOGIN_DEFS"
    fi
}

# Append the configured serial device to securetty when it is not already present.
tty_config_securetty() {
    tty_backup_orig "$TTY_SECURETTY"
    if [ -f "$TTY_SECURETTY" ]; then
        if grep "^$TTY_DEV\$" "$TTY_SECURETTY" >/dev/null 2>&1; then
            return 0
        fi
    fi
    echo "$TTY_DEV" >> "$TTY_SECURETTY"
}

# Entry point for enabling the target serial login console.
_tty_config() {
    tty_set_defaults
    echo "### Enabling serial console on $TTY_DEV..."

    if tty_detect_paths; then
        tty_run_step tty_config_inittab &&
        tty_run_step tty_config_login_defs &&
        tty_run_step tty_config_securetty
    fi

    return 0
}
