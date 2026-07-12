# shellcheck shell=bash
#
# Shared QMP driver blocks for Red Hat's early Perl/dialog installer.
#
# This covers the installer family used by Red Hat 1.1 through 3.0.3. Release
# install.sh files should source it, set the small version-specific variables
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
    vga_wait -l "$BOOT_PROMPT"
    kb_type -n "$BOOT_COMMAND"
}

load_single_ramdisk() {
    local image
    image=$1

    vga_wait -l "VFS: Insert ramdisk floppy and press ENTER"
    script_change_floppy "$image"
    kb_press ret
}

load_two_ramdisks() {
    load_single_ramdisk ramdisk1.img
    vga_wait -l "RHL: Insert ramdisk 2 floppy and press ENTER"
    script_change_floppy ramdisk2.img
    kb_press ret
}

insert_boot_disk() {
    vga_wait "Please insert your BOOT disk"
    script_change_floppy boot.img
    kb_press ret
}

partition_disk() {
    local prompt
    prompt=$1

    vga_wait "$prompt"
    kb_press alt-f2
    fdisk_swap_root /dev/hda 64
    kb_press alt-f1
    vga_wait "$prompt"
    kb_press n
}

configure_network_common() {
    local order
    order=$1

    redhat_update_network_names
    kb_press y
    vga_wait "What hostname have you selected for this computer?"
    kb_type -n "$NET_HOSTNAME"
    vga_wait "What domain name is this computer part of?"
    kb_type -n "$NET_DOMAINNAME"
    vga_wait "What is the fully qualified domain name (FQDN) of this computer?"
    kb_repeat backspace 30 # erase default
    kb_type -n "$NET_FQDN"
    vga_wait "What is the IP address of this computer?"
    kb_type -n "$NET_IPADDR"
    if [ "$order" = "network-first" ]; then
        vga_wait "What is the network address of this computer?"
        kb_repeat backspace 15 # erase default
        kb_type -n "$NET_NETWORK"
        vga_wait "What is the netmask used by this computer?"
        kb_repeat backspace 15 # erase default
        kb_type -n "$NET_NETMASK"
    else
        vga_wait "What is the netmask used by this computer?"
        kb_repeat backspace 15 # erase default
        kb_type -n "$NET_NETMASK"
        vga_wait "What is the network address of this computer?"
        kb_repeat backspace 15 # erase default
        kb_type -n "$NET_NETWORK"
    fi
    vga_wait "What is the broadcast address used by this computer?"
    kb_repeat backspace 15 # erase default
    kb_type -n "$NET_BROADCAST"
    vga_wait "Does this computer use a gateway?"
    kb_press y
    vga_wait "What is the IP address of the gateway used by this computer?"
    kb_repeat backspace 15 # erase default
    kb_type -n "$NET_GATEWAY"
    vga_wait "Does this computer use a nameserver?"
    kb_press y
    vga_wait "What is the IP address of the nameserver?"
    kb_repeat backspace 15 # erase default
    kb_type -n "$NET_NAMESERVER"
    vga_wait "Does this computer use another nameserver?"
    kb_press n
    vga_wait "Is this correct?"
    kb_press y
}

format_root() {
    vga_wait "Use the spacebar to select all partitions to format."
    kb_press spc
    kb_press ret
    vga_wait "Are you absolutely certain that you want to format?"
    kb_press y
}

configure_x11_common() {
    vga_wait "Which type of mouse do you have?"
    kb_press p # selects ps2-bus
    kb_press ret
    vga_wait "Do you want to autoprobe?"
    kb_press n
    vga_wait "Pick a chipset."
    kb_press ret # don't care; we'll overwrite this later
    vga_wait "How much memory does your card have."
    kb_press ret
    vga_wait "Enter your clocks, separated by spaces."
    kb_press ret
    vga_wait "Please choose a monitor."
    kb_press ret
}

confirm_network_configured() {
    vga_wait "Networking has already been configured"
    kb_press y
}

skip_modem_setup() {
    vga_wait "No Modem"
    kb_press ret
}

configure_system_clock() {
    local clock_prompt
    clock_prompt=$1

    vga_wait "$clock_prompt"
    kb_press ret
}

select_timezone() {
    vga_wait "Pick a time zone."
    kb_press ret
}

select_keymap() {
    vga_wait "Select a keymap."
    kb_press ret
}

install_lilo() {
    vga_wait "Do you want to install LILO?"
    kb_press y
    vga_wait "Where do you want to install LILO?"
    kb_press ret
    vga_wait "Do you need to specify hardware parameters?"
    kb_press n
    vga_wait "Do you want to indicate another operating system"
    kb_press n
}

skip_user_account() {
    vga_wait "Do you want to create a user account?"
    kb_press n
}

set_blank_root_password() {
    local confirm_twice
    confirm_twice=${1:-false}

    vga_wait "You will now enter a password for the root user"
    kb_press ret
    if [ "$confirm_twice" = "true" ]; then
        kb_press ret # blank password
    fi
}

reboot_to_installed_system() {
    vga_wait "Reboot now?"
    kb_press y
    vga_wait "Be sure to remove the boot floppy from your floppy drive!"
    script_set_boot c
    kb_press ret
}

redhat_run_postinst() {
    redhat_update_network_names
    LOGIN_PROMPT="$NET_FQDN login:"
    SHELL_PROMPT="[root@$NET_HOSTNAME /root]#"
    script_run_postinst
}
