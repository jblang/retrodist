# shellcheck shell=sh
# Set MOD_LAYOUT to slackware or debian; return 1 if neither is detected.
mod_detect_layout() {
    if [ -f "$ETC_D/rc.d/rc.modules" ]; then
        MOD_LAYOUT=slackware
        log INFO "Detected Slackware-style module configuration"
    elif [ -f "$ETC_D/init.d/modules" ] || [ -f "$ETC_D/init.d/modutils" ]; then
        MOD_LAYOUT=debian
        log INFO "Detected Debian-style module configuration"
    else
        log INFO "No supported module configuration detected; skipping"
        return 1
    fi
}

# Split a module spec "name [opts...]" into MOD_NAME and MOD_OPTIONS.
mod_parse() {
    set -- $1
    MOD_NAME=$1
    shift
    MOD_OPTIONS="$*"
    log DEBUG "Parsed module spec:"
    log DEBUG "  name=$MOD_NAME"
    log DEBUG "  options=$MOD_OPTIONS"
}

# Copy src to dst only when dst does not already exist.
mod_backup_file() {
    if [ -f "$1" ] && [ ! -f "$2" ]; then
        log DEBUG "Creating backup file: $2"
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
        mod_backup_suffix "$ETC_D/modules"
        mod_backup_suffix "$ETC_D/conf.modules"
    elif [ "$MOD_LAYOUT" = "slackware" ]; then
        mod_backup_suffix "$ETC_D/rc.d/rc.modules"
    fi
}

# Append a module name to /etc/modules.
mod_add_debian() {
    log INFO "Updating file: $ETC_D/modules"
    echo "$1" >>"$ETC_D/modules"
}

# Append a modprobe line to rc.modules.
mod_add_slackware() {
    MOD_ADD_NAME="$1"
    MOD_ADD_OPTIONS="$2"
    log INFO "Updating file: $ETC_D/rc.d/rc.modules"
    if [ -n "$MOD_ADD_OPTIONS" ]; then
        echo "/sbin/modprobe $MOD_ADD_NAME $MOD_ADD_OPTIONS" >>"$ETC_D/rc.d/rc.modules"
    else
        echo "/sbin/modprobe $MOD_ADD_NAME" >>"$ETC_D/rc.d/rc.modules"
    fi
}

# Enable a single module spec, writing options to conf.modules on Debian.
mod_enable() {
    mod_parse "$1"
    if [ "$MOD_LAYOUT" = "debian" ]; then
        mod_add_debian "$MOD_NAME"
        if [ -n "$MOD_OPTIONS" ]; then
            log INFO "Updating file: $ETC_D/conf.modules"
            echo "options $MOD_NAME $MOD_OPTIONS" >>"$ETC_D/conf.modules"
        fi
    elif [ "$MOD_LAYOUT" = "slackware" ]; then
        mod_add_slackware "$MOD_NAME" "$MOD_OPTIONS"
    fi
}

# Enable each newline-separated "name [opts...]" entry in MOD_ENABLE.
mod_enable_boot_modules() {
    if [ -z "$MOD_ENABLE" ]; then
        log INFO "No MOD_ENABLE set; skipping"
        return 0
    fi
    MOD_IFS_SAVE="$IFS"
    IFS='
'
    for spec in $MOD_ENABLE; do
        IFS="$MOD_IFS_SAVE"
        if [ -n "$spec" ]; then
            log INFO "Enabling module: $spec"
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
    log INFO "Configuring kernel modules..."
    log INFO "Module configuration:"
    log INFO "  MOD_ENABLE=$MOD_ENABLE"

    mod_detect_layout || return 0
    mod_backup_files
    mod_enable_boot_modules
}
