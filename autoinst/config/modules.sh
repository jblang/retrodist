# shellcheck shell=sh
# Set MOD_LAYOUT to slackware or debian; return 1 if neither is detected.
mod_detect_layout() {
    if [ -f "$ETCPATH/rc.d/rc.modules" ]; then
        MOD_LAYOUT=slackware
        log_info "Detected Slackware-style module configuration"
    elif [ -f "$ETCPATH/init.d/modules" ] || [ -f "$ETCPATH/init.d/modutils" ]; then
        MOD_LAYOUT=debian
        log_info "Detected Debian-style module configuration"
    else
        log_info "No supported module configuration detected; skipping"
        return 1
    fi
}

# Split a module spec "name [opts...]" into MOD_NAME and MOD_OPTIONS.
mod_parse() {
    set -- $1
    MOD_NAME=$1
    shift
    MOD_OPTIONS="$*"
    log_debug "Parsed module spec:"
    log_debug "  name=$MOD_NAME"
    log_debug "  options=$MOD_OPTIONS"
}

# Copy src to dst only when dst does not already exist.
mod_backup_file() {
    if [ -f "$1" ] && [ ! -f "$2" ]; then
        log_debug "Creating backup file: $2"
        cp "$1" "$2"
    fi
}

# Back up a file with a ~ suffix.
mod_backup_suffix() {
    mod_backup_file "$1" "$1~"
}

# Back up module config files before first modification.
mod_backup_files() {
    if [ "$MOD_LAYOUT" = "debian" ]; then
        mod_backup_suffix "$ETCPATH/modules"
        mod_backup_suffix "$ETCPATH/conf.modules"
    elif [ "$MOD_LAYOUT" = "slackware" ]; then
        mod_backup_suffix "$ETCPATH/rc.d/rc.modules"
    fi
}

# Append a module name to /etc/modules.
mod_add_debian() {
    log_info "Updating file: $ETCPATH/modules"
    echo "$1" >>"$ETCPATH/modules"
}

# Append a modprobe line to rc.modules.
mod_add_slackware() {
    MOD_ADD_NAME="$1"
    MOD_ADD_OPTIONS="$2"
    log_info "Updating file: $ETCPATH/rc.d/rc.modules"
    if [ -n "$MOD_ADD_OPTIONS" ]; then
        echo "/sbin/modprobe $MOD_ADD_NAME $MOD_ADD_OPTIONS" >>"$ETCPATH/rc.d/rc.modules"
    else
        echo "/sbin/modprobe $MOD_ADD_NAME" >>"$ETCPATH/rc.d/rc.modules"
    fi
}

# Enable a single module spec, writing options to conf.modules on Debian.
mod_enable() {
    mod_parse "$1"
    if [ "$MOD_LAYOUT" = "debian" ]; then
        mod_add_debian "$MOD_NAME"
        if [ -n "$MOD_OPTIONS" ]; then
            log_info "Updating file: $ETCPATH/conf.modules"
            echo "options $MOD_NAME $MOD_OPTIONS" >>"$ETCPATH/conf.modules"
        fi
    elif [ "$MOD_LAYOUT" = "slackware" ]; then
        mod_add_slackware "$MOD_NAME" "$MOD_OPTIONS"
    fi
}

# Enable each newline-separated "name [opts...]" entry in MOD_ENABLE.
mod_enable_boot_modules() {
    if [ -z "$MOD_ENABLE" ]; then
        log_info "No MOD_ENABLE set; skipping"
        return 0
    fi
    MOD_IFS_SAVE="$IFS"
    IFS='
'
    for spec in $MOD_ENABLE; do
        IFS="$MOD_IFS_SAVE"
        if [ -n "$spec" ]; then
            log_info "Enabling module: $spec"
            mod_enable "$spec"
        fi
        IFS='
'
    done
    IFS="$MOD_IFS_SAVE"
}

# Configure kernel module autoloading on the target system.
_mod_config() {
    log_div
    log_info "Configuring kernel modules..."
    log_info "Module configuration:"
    log_info "  MOD_ENABLE=$MOD_ENABLE"

    mod_detect_layout || return 0
    mod_backup_files
    mod_enable_boot_modules
}
