# shellcheck shell=bash
#
# Shared QMP driver blocks for Red Hat's early Perl/dialog installer.
#
# This covers the installer family used by Red Hat 1.1 through 3.0.3. Release
# script.sh files should source it, set the small version-specific variables
# they need, then call the relevant blocks or driver.

BOOT_PROMPT="boot:"
BOOT_COMMAND=
NET_HOSTNAME=redhat
NET_DOMAINNAME=retro.net
NET_FQDN=$NET_HOSTNAME.$NET_DOMAINNAME
NET_IPADDR=10.0.2.15
NET_NETMASK=255.255.255.0
NET_NETWORK=10.0.2.0
NET_BROADCAST=10.0.2.255
NET_GATEWAY=10.0.2.2
NET_NAMESERVER=10.0.2.3
LOGIN_PROMPT="$NET_FQDN login:"

redhat_update_network_names() {
    NET_FQDN=$NET_HOSTNAME.$NET_DOMAINNAME
}

boot_loader() {
    screen_wait -l "$BOOT_PROMPT"
    kb_send_line "$BOOT_COMMAND"
}

load_single_ramdisk() {
    local image
    image=$1

    screen_wait -l "VFS: Insert ramdisk floppy and press ENTER"
    script_change_floppy "$image"
    kb_press_key ret
}

load_two_ramdisks() {
    load_single_ramdisk ramdisk1.img
    screen_wait -l "RHL: Insert ramdisk 2 floppy and press ENTER"
    script_change_floppy ramdisk2.img
    kb_press_key ret
}

insert_boot_disk() {
    screen_wait "Please insert your BOOT disk"
    script_change_floppy boot.img
    kb_press_key ret
}

partition_disk() {
    local prompt
    prompt=$1

    screen_wait "$prompt"
    kb_press_key alt-f2
    script_fdisk /dev/hda 64
    kb_press_key alt-f1
    screen_wait "$prompt"
    kb_press_key n
}

configure_network_common() {
    local order
    order=$1

    redhat_update_network_names
    kb_press_key y
    screen_wait "What hostname have you selected for this computer?"
    kb_send_line "$NET_HOSTNAME"
    screen_wait "What domain name is this computer part of?"
    kb_send_line "$NET_DOMAINNAME"
    screen_wait "What is the fully qualified domain name (FQDN) of this computer?"
    kb_press_key backspace 30 # erase default
    kb_send_line "$NET_FQDN"
    screen_wait "What is the IP address of this computer?"
    kb_send_line "$NET_IPADDR"
    if [ "$order" = "network-first" ]; then
        screen_wait "What is the network address of this computer?"
        kb_press_key backspace 15 # erase default
        kb_send_line "$NET_NETWORK"
        screen_wait "What is the netmask used by this computer?"
        kb_press_key backspace 15 # erase default
        kb_send_line "$NET_NETMASK"
    else
        screen_wait "What is the netmask used by this computer?"
        kb_press_key backspace 15 # erase default
        kb_send_line "$NET_NETMASK"
        screen_wait "What is the network address of this computer?"
        kb_press_key backspace 15 # erase default
        kb_send_line "$NET_NETWORK"
    fi
    screen_wait "What is the broadcast address used by this computer?"
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_BROADCAST"
    screen_wait "Does this computer use a gateway?"
    kb_press_key y
    screen_wait "What is the IP address of the gateway used by this computer?"
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_GATEWAY"
    screen_wait "Does this computer use a nameserver?"
    kb_press_key y
    screen_wait "What is the IP address of the nameserver?"
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_NAMESERVER"
    screen_wait "Does this computer use another nameserver?"
    kb_press_key n
    screen_wait "Is this correct?"
    kb_press_key y
}

format_root() {
    screen_wait "Use the spacebar to select all partitions to format."
    kb_press_key spc
    kb_press_key ret
    screen_wait "Are you absolutely certain that you want to format?"
    kb_press_key y
}

configure_x11_common() {
    screen_wait "Which type of mouse do you have?"
    kb_press_key p # selects ps2-bus
    kb_press_key ret
    screen_wait "Do you want to autoprobe?"
    kb_press_key n
    screen_wait "Pick a chipset."
    kb_press_key ret # don't care; we'll overwrite this later
    screen_wait "How much memory does your card have."
    kb_press_key ret
    screen_wait "Enter your clocks, separated by spaces."
    kb_press_key ret
    screen_wait "Please choose a monitor."
    kb_press_key ret
}

confirm_network_configured() {
    screen_wait "Networking has already been configured"
    kb_press_key y
}

skip_modem_setup() {
    screen_wait "No Modem"
    kb_press_key ret
}

configure_system_clock() {
    local clock_prompt
    clock_prompt=$1

    screen_wait "$clock_prompt"
    kb_press_key ret
}

select_timezone() {
    screen_wait "Pick a time zone."
    kb_press_key ret
}

select_keymap() {
    screen_wait "Select a keymap."
    kb_press_key ret
}

install_lilo() {
    screen_wait "Do you want to install LILO?"
    kb_press_key y
    screen_wait "Where do you want to install LILO?"
    kb_press_key ret
    screen_wait "Do you need to specify hardware parameters?"
    kb_press_key n
    screen_wait "Do you want to indicate another operating system"
    kb_press_key n
}

skip_user_account() {
    screen_wait "Do you want to create a user account?"
    kb_press_key n
}

set_blank_root_password() {
    local confirm_twice
    confirm_twice=${1:-false}

    screen_wait "You will now enter a password for the root user"
    kb_press_key ret
    if [ "$confirm_twice" = "true" ]; then
        kb_press_key ret # blank password
    fi
}

reboot_to_installed_system() {
    screen_wait "Reboot now?"
    kb_press_key y
    screen_wait "Be sure to remove the boot floppy from your floppy drive!"
    script_set_boot c
    kb_press_key ret
}

run_first_boot_autoconf() {
    redhat_update_network_names
    LOGIN_PROMPT="$NET_FQDN login:"
    SHELL_PROMPT="[root@$NET_HOSTNAME /root]#"
    script_run_autoconf
}
