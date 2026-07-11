# shellcheck shell=sh
# Fill unset network configuration variables with QEMU-friendly defaults.
net_set_defaults() {
    NET_IPADDR=${NET_IPADDR:-10.0.2.15}
    NET_NETMASK=${NET_NETMASK:-255.255.255.0}
    NET_NETWORK=${NET_NETWORK:-10.0.2.0}
    NET_BROADCAST=${NET_BROADCAST:-10.0.2.255}
    NET_GATEWAY=${NET_GATEWAY:-10.0.2.2}
    NET_NAMESERVER=${NET_NAMESERVER:-10.0.2.3}
    NET_DOMAINNAME=${NET_DOMAINNAME:-retro.net}

    log INFO "Network configuration:"
    log INFO "  HOSTNAME=$NET_HOSTNAME"
    log INFO "  IPADDR=$NET_IPADDR"
    log INFO "  DOMAIN=$NET_DOMAINNAME"
    log INFO "  NETMASK=$NET_NETMASK"
    log INFO "  NETWORK=$NET_NETWORK"
    log INFO "  BROADCAST=$NET_BROADCAST"
    log INFO "  GATEWAY=$NET_GATEWAY"
    log INFO "  GATEWAY_HWADDR=$NET_GATEWAY_HWADDR"
    log INFO "  NAMESERVER=$NET_NAMESERVER"
    log INFO "  NAMESERVER_HWADDR=$NET_NAMESERVER_HWADDR"
}

# Emit /etc/hosts entries for localhost and the configured host.
net_build_etc_hosts() {
    echo "127.0.0.1	localhost"
    if [ -n "$NET_DOMAINNAME" ] && [ "$NET_DOMAINNAME" != "none" ]; then
        echo "$NET_IPADDR		$NET_HOSTNAME.$NET_DOMAINNAME	$NET_HOSTNAME"
    else
        echo "$NET_IPADDR		$NET_HOSTNAME"
    fi
    if [ -n "$NET_GATEWAY" ]; then
        echo "$NET_GATEWAY		gateway"
    fi
    if [ -n "$NET_NAMESERVER" ]; then
        echo "$NET_NAMESERVER		nameserver"
    fi
}

# Emit resolver configuration for the configured domain and nameserver.
net_build_resolv_conf() {
    echo "# domain $NET_DOMAINNAME"
    echo "# search $NET_DOMAINNAME"
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
    echo "$NET_IFCONFIG_PATH lo 127.0.0.1"
    echo "$NET_ROUTE_LOOPBACK"
    echo
    echo "IPADDR=$NET_IPADDR"
    echo "NETMASK=$NET_NETMASK"
    echo "NETWORK=$NET_NETWORK"
    echo "BROADCAST=$NET_BROADCAST"
    echo "GATEWAY=$NET_GATEWAY"
    echo "NAMESERVER=$NET_NAMESERVER"
    echo
    echo "$NET_IFCONFIG_PATH eth0 \$IPADDR netmask \$NETMASK broadcast \$BROADCAST"
    echo "$NET_ROUTE_NETWORK"
    if [ -n "$NET_GATEWAY_HWADDR" ]; then
        echo "$NET_ARP_PATH -s \$GATEWAY $NET_GATEWAY_HWADDR"
    fi
    if [ -n "$NET_NAMESERVER_HWADDR" ]; then
        echo "$NET_ARP_PATH -s \$NAMESERVER $NET_NAMESERVER_HWADDR"
    fi
    echo "$NET_ROUTE_PATH add default gw \$GATEWAY metric 1"
}

# Rewrite an rc.net-style /etc/hosts file with host, network, and router entries.
net_build_rcnet_hosts() {
    # Note: tab must separate IP and hostnames below, not spaces
    sed "s/.*$NET_HOSTNAME$/$NET_IPADDR	$NET_HOSTNAME/" "$NET_HOSTS_PATH~" |
        sed "s/.*network$/$NET_NETWORK	network/" |
        sed "s/.*router$/$NET_GATEWAY	router/"
}

# Copy a source file to a destination only once, preserving the first backup.
net_backup_file() {
    if [ -f "$1" ] && [ ! -f "$2" ]; then
        log DEBUG "Creating backup file: $2"
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
    if [ -f "$ETC_D/HOSTNAME" ]; then
        NET_HOSTNAME_PATH="$ETC_D/HOSTNAME"
    else
        NET_HOSTNAME_PATH="$ETC_D/hostname"
    fi
    log DEBUG "Detected hostname file: $NET_HOSTNAME_PATH"
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
    log DEBUG "Detected ifconfig command: $NET_IFCONFIG_PATH"
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
    log DEBUG "Detected route command: $NET_ROUTE_PATH"
}

# Choose an arp path available to the target system.
net_detect_arp_path() {
    if [ -z "$NET_ARP_PATH" ]; then
        if [ -x "/usr/sbin/arp" ]; then
            NET_ARP_PATH="/usr/sbin/arp"
        elif [ -x "/sbin/arp" ]; then
            NET_ARP_PATH="/sbin/arp"
        else
            NET_ARP_PATH=arp
        fi
    fi
    log DEBUG "Detected arp command: $NET_ARP_PATH"
}

# Detect which network initialization style this target system uses.
net_detect_init_path() {
    if [ -f "$ETC_D/rc.d/rc.inet1" ]; then
        NET_INIT_SCRIPT_PATH="$ETC_D/rc.d/rc.inet1"
        log INFO "Detected network style: rc.inet1"
    elif [ -d "$ETC_D/init.d" ]; then
        NET_INIT_SCRIPT_PATH="$ETC_D/init.d/network"
        log INFO "Detected network style: SysV init.d"
    elif [ -f "$ETC_D/rc.net" ]; then
        NET_RC_NET_PATH="$ETC_D/rc.net"
        log INFO "Detected network style: rc.net"
    else
        log WARN "No supported network init layout found."
        return 1
    fi
}

# Populate derived network config paths and detect target command paths.
net_detect_paths() {
    NET_HOSTS_PATH="$ETC_D/hosts"
    NET_RESOLV_CONF_PATH="$ETC_D/resolv.conf"
    NET_NETWORKS_PATH="$ETC_D/networks"

    net_detect_hostname_path
    net_detect_ifconfig_path
    net_detect_route_path
    net_detect_arp_path
    net_detect_init_path
}

# Write hostname, init script, hosts, resolver, and networks files.
net_config_standard() {
    net_backup_suffix "$NET_HOSTNAME_PATH"
    log INFO "Creating file: $NET_HOSTNAME_PATH"
    echo "$NET_HOSTNAME" >"$NET_HOSTNAME_PATH"
    chmod 644 "$NET_HOSTNAME_PATH"

    net_backup_suffix "$NET_INIT_SCRIPT_PATH"
    log INFO "Creating file: $NET_INIT_SCRIPT_PATH"
    net_build_init_script >"$NET_INIT_SCRIPT_PATH"
    chmod 755 "$NET_INIT_SCRIPT_PATH"

    net_backup_suffix "$NET_HOSTS_PATH"
    log INFO "Creating file: $NET_HOSTS_PATH"
    net_build_etc_hosts >"$NET_HOSTS_PATH"
    chmod 644 "$NET_HOSTS_PATH"

    net_backup_suffix "$NET_RESOLV_CONF_PATH"
    log INFO "Creating file: $NET_RESOLV_CONF_PATH"
    net_build_resolv_conf >"$NET_RESOLV_CONF_PATH"
    chmod 644 "$NET_RESOLV_CONF_PATH"

    if [ "$NET_ANCIENT_ROUTE" != "1" ]; then
        net_backup_suffix "$NET_NETWORKS_PATH"
        if grep -q "localnet" "$NET_NETWORKS_PATH" 2>/dev/null; then
            log INFO "$NET_NETWORKS_PATH already contains localnet entry; skipping"
        else
            log INFO "Updating file: $NET_NETWORKS_PATH"
            net_build_etc_networks >>"$NET_NETWORKS_PATH"
            chmod 644 "$NET_NETWORKS_PATH"
        fi
    else
        log INFO "Skipping $NET_NETWORKS_PATH because NET_ANCIENT_ROUTE=1"
    fi
}

# Configure rc.net-style networking through its non-standard /etc/hosts flow.
net_config_rc_net() {
    # rc.net-style non-standard network configuration via /etc/hosts only
    log INFO "Configuring networking via hosts..."

    net_backup_suffix "$NET_HOSTS_PATH"
    log INFO "Creating file: $NET_HOSTS_PATH"
    net_build_rcnet_hosts >"$NET_HOSTS_PATH"

    # rc.net style uses /etc/host (singular) for hostname
    NET_HOST_PATH="$ETC_D/host"
    net_backup_suffix "$NET_HOST_PATH"
    log INFO "Creating file: $NET_HOST_PATH"
    echo "$NET_HOSTNAME" >"$NET_HOST_PATH"
    chmod 644 "$NET_HOST_PATH"

    # rc.net style uses /etc/domain for domain name
    if [ -n "$NET_DOMAINNAME" ] && [ "$NET_DOMAINNAME" != "none" ]; then
        NET_DOMAIN_PATH="$ETC_D/domain"
        net_backup_suffix "$NET_DOMAIN_PATH"
        log INFO "Creating file: $NET_DOMAIN_PATH"
        echo "$NET_DOMAINNAME" >"$NET_DOMAIN_PATH"
        chmod 644 "$NET_DOMAIN_PATH"
    fi

    net_backup_suffix "$NET_RESOLV_CONF_PATH"
    log INFO "Creating file: $NET_RESOLV_CONF_PATH"
    net_build_resolv_conf >"$NET_RESOLV_CONF_PATH"
    chmod 644 "$NET_RESOLV_CONF_PATH"
}

# Entry point for applying target network configuration.
_net_config() {
    log_div
    log INFO "Configuring networking..."

    net_set_defaults

    if net_detect_paths; then
        if [ -n "$NET_INIT_SCRIPT_PATH" ]; then
            log INFO "Using standard network configuration flow"
            net_config_standard
        elif [ -n "$NET_RC_NET_PATH" ]; then
            log INFO "Using rc.net hosts-based network configuration flow"
            net_config_rc_net
        fi
    else
        log WARN "Skipping network file configuration because paths were not detected"
    fi
}
