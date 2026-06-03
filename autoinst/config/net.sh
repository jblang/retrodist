# Fill unset network configuration variables with QEMU-friendly defaults.
net_set_defaults() {
    NET_NETMASK=${NET_NETMASK:-255.255.255.0}
    NET_NETWORK=${NET_NETWORK:-10.0.2.0}
    NET_BROADCAST=${NET_BROADCAST:-10.0.2.255}
    NET_GATEWAY=${NET_GATEWAY:-10.0.2.1}
    NET_NAMESERVER=${NET_NAMESERVER:-10.0.2.1}
    NET_DOMAINNAME=${NET_DOMAINNAME:-retro.net}

    NET_ETCPATH=${NET_ETCPATH:-/etc}
    NET_RCPATH=${NET_RCPATH:-$NET_ETCPATH/rc.d}
    NET_MODULE=${NET_MODULE:-tulip}
}

# Emit the hostname file contents, including a domain when configured.
net_build_etc_hostname() {
    if [ -z "$NET_DOMAINNAME" ]; then
        echo "$NET_HOSTNAME"
    else
        echo "$NET_HOSTNAME.$NET_DOMAINNAME"
    fi
}

# Emit /etc/hosts entries for localhost and the configured host.
net_build_etc_hosts() {
    echo "127.0.0.1	localhost"
    if [ -n "$NET_DOMAINNAME" ] && [ "$NET_DOMAINNAME" != "none" ]; then
        echo "$NET_IPADDR		$NET_HOSTNAME.$NET_DOMAINNAME	$NET_HOSTNAME"
    else
        echo "$NET_IPADDR		$NET_HOSTNAME"
    fi
}

# Emit resolver configuration for the configured domain and nameserver.
net_build_resolv_conf() {
    echo "domain $NET_DOMAINNAME"
    echo "search $NET_DOMAINNAME"
    if [ -n "$NET_NAMESERVER" ]; then
        echo "nameserver $NET_NAMESERVER"
    fi
}

# Emit the legacy /etc/networks entry for the local network.
net_build_etc_networks() {
    echo "localnet $NET_NETWORK"
}

# Emit a SysV-style network init script for loopback and eth0.
net_build_init_script() {
    if [ "$NET_ANCIENT_ROUTE" = "1" ]; then
        NET_ROUTE_LOOPBACK="$NET_ROUTE_PATH add 127.0.0.1"
        NET_ROUTE_NETWORK="$NET_ROUTE_PATH -n add \$NETWORK"
    else
        NET_ROUTE_LOOPBACK="$NET_ROUTE_PATH add -net 127.0.0.0"
        NET_ROUTE_NETWORK="$NET_ROUTE_PATH add -net \$NETWORK"
    fi
    echo "#!/bin/sh"
    if [ "$NET_HOSTNAME_INIT_SET" = "1" ]; then
        echo "hostname -S"
    fi
    cat <<EOF
$NET_IFCONFIG_PATH lo 127.0.0.1
$NET_ROUTE_LOOPBACK

IPADDR=$NET_IPADDR
NETMASK=$NET_NETMASK
NETWORK=$NET_NETWORK
BROADCAST=$NET_BROADCAST
GATEWAY=$NET_GATEWAY

$NET_IFCONFIG_PATH eth0 \$IPADDR netmask \$NETMASK broadcast \$BROADCAST
$NET_ROUTE_NETWORK
$NET_ROUTE_PATH add default gw \$GATEWAY metric 1
EOF
}

# Rewrite an SLS /etc/hosts file with host, network, and router entries.
net_build_sls_hosts() {
    # Note: tab must separate IP and hostnames below, not spaces
    sed "s/.*$NET_HOSTNAME$/$NET_IPADDR	$NET_HOSTNAME/" "$NET_HOSTS_PATH~" |
        sed "s/.*network$/$NET_NETWORK	network/" |
        sed "s/.*router$/$NET_GATEWAY	router/"
}

# Emit the Slackware rc.modules network driver load command.
net_build_rc_modules() {
    if [ "$NET_MODULE" != "none" ]; then
        echo "/sbin/modprobe $NET_MODULE"
    fi
}

# Emit Debian modutils alias and option lines for eth0.
net_build_conf_modules() {
    echo "alias eth0 $NET_MODULE_NAME"
    if [ -n "$NET_MODULE_OPTIONS" ]; then
        echo "options $NET_MODULE_NAME $NET_MODULE_OPTIONS"
    fi
}

# Split NET_MODULE into a module name and optional module arguments.
net_parse_module() {
    set -- $NET_MODULE
    NET_MODULE_NAME=$1
    shift
    NET_MODULE_OPTIONS="$*"
}

# Copy a source file to a destination only once, preserving the first backup.
net_backup_file() {
    if [ -f "$1" ] && [ ! -f "$2" ]; then
        cp "$1" "$2"
    fi
}

# Back up a file using the default "~" suffix or a caller-provided suffix.
net_backup_suffix() {
    if [ -z "$2" ]; then
        net_backup_file "$1" "$1~"
    else
        net_backup_file "$1" "$1$2"
    fi
}

# Choose the target hostname file path used by the installed system.
net_detect_hostname_path() {
    if [ -f "$NET_ETCPATH/HOSTNAME" ]; then
        NET_HOSTNAME_PATH="$NET_ETCPATH/HOSTNAME"
    else
        NET_HOSTNAME_PATH="$NET_ETCPATH/hostname"
    fi
}

# Choose an ifconfig path available to the installer environment.
net_detect_ifconfig_path() {
    if [ -z "$NET_IFCONFIG_PATH" ]; then
        if [ -x "/sbin/ifconfig" ]; then
            NET_IFCONFIG_PATH="/sbin/ifconfig"
        elif [ -x "/etc/ifconfig" ]; then
            NET_IFCONFIG_PATH="/etc/ifconfig"
        else
            NET_IFCONFIG_PATH=ifconfig
        fi
    fi
}

# Choose a route path available to the installer environment.
net_detect_route_path() {
    if [ -z "$NET_ROUTE_PATH" ]; then
        if [ -x "/sbin/route" ]; then
            NET_ROUTE_PATH="/sbin/route"
        elif [ -x "/etc/route" ]; then
            NET_ROUTE_PATH="/etc/route"
        else
            NET_ROUTE_PATH=route
        fi
    fi
}

# Detect which network initialization style this target system uses.
net_detect_init_path() {
    if [ -f "$NET_RCPATH/rc.inet1" ]; then
        NET_INIT_SCRIPT_PATH="$NET_RCPATH/rc.inet1"
    elif [ -d "$NET_ETCPATH/init.d" ]; then
        NET_INIT_SCRIPT_PATH="$NET_ETCPATH/init.d/network"
    elif [ -f "$NET_ETCPATH/rc.net" ]; then
        NET_RC_NET_PATH="$NET_ETCPATH/rc.net"
    else
        return 1
    fi
}

# Populate derived network config paths and detect target command paths.
net_detect_paths() {
    NET_HOSTS_PATH="$NET_ETCPATH/hosts"
    NET_RESOLV_CONF_PATH="$NET_ETCPATH/resolv.conf"
    NET_NETWORKS_PATH="$NET_ETCPATH/networks"

    net_detect_hostname_path
    net_detect_ifconfig_path
    net_detect_route_path
    net_detect_init_path
}

# Write hostname, init script, hosts, resolver, and networks files.
net_config_standard() {
    net_backup_suffix "$NET_HOSTNAME_PATH"
    net_build_etc_hostname > "$NET_HOSTNAME_PATH"
    chmod 644 "$NET_HOSTNAME_PATH"

    net_backup_suffix "$NET_INIT_SCRIPT_PATH"
    net_build_init_script > "$NET_INIT_SCRIPT_PATH"
    chmod 755 "$NET_INIT_SCRIPT_PATH"

    net_backup_suffix "$NET_HOSTS_PATH"
    net_build_etc_hosts > "$NET_HOSTS_PATH"
    chmod 644 "$NET_HOSTS_PATH"

    net_backup_suffix "$NET_RESOLV_CONF_PATH"
    net_build_resolv_conf > "$NET_RESOLV_CONF_PATH"
    chmod 644 "$NET_RESOLV_CONF_PATH"

    if [ "$NET_ANCIENT_ROUTE" != "1" ]; then
        net_backup_suffix "$NET_NETWORKS_PATH"
        net_build_etc_networks >> "$NET_NETWORKS_PATH"
        chmod 644 "$NET_NETWORKS_PATH"
    fi
}

# Configure SLS networking through its non-standard /etc/hosts flow.
net_config_rc_net() {
    # SLS's non-standard network configuration via /etc/hosts only
    echo '## Configuring networking via hosts...'

    net_backup_suffix "$NET_HOSTS_PATH"
    net_build_sls_hosts > "$NET_HOSTS_PATH"
}

# Enable the selected network module on Debian modutils-based systems.
net_enable_module_debian() {
    if [ "$NET_MODULE" = "none" ]; then
        return 0
    fi

    net_parse_module
    net_backup_suffix "$NET_ETCPATH/conf.modules"
    echo "$NET_MODULE_NAME" >> "$NET_ETCPATH/modules"
    net_build_conf_modules >> "$NET_ETCPATH/conf.modules"
    # suffix must be .old because rc scripts key off its existence
    net_backup_suffix "$NET_ETCPATH/modules" ".old"
    chmod 644 "$NET_ETCPATH/modules" "$NET_ETCPATH/conf.modules"
}

# Enable the selected network module through Slackware rc.modules.
net_enable_module_slackware() {
    net_backup_suffix "$NET_RCPATH/rc.modules"
    net_build_rc_modules >> "$NET_RCPATH/rc.modules"
}

# Dispatch network module setup based on the target module loader layout.
net_enable_module() {
    if [ -f "$NET_ETCPATH/init.d/modules" ]; then
        net_enable_module_debian
    elif [ -f "$NET_RCPATH/rc.modules" ]; then
        net_enable_module_slackware
    fi
}

# Entry point for applying target network configuration.
_net_config() {
    echo '### Configuring networking...'

    net_set_defaults

    if net_detect_paths; then
        if [ -n "$NET_INIT_SCRIPT_PATH" ]; then
            net_config_standard
        elif [ -n "$NET_RC_NET_PATH" ]; then
            net_config_rc_net
        fi
    fi

    net_enable_module
}
