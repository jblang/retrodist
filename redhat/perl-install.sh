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
NET_IPADDR=10.0.2.15
NET_GATEWAY=0.2.2
NET_NAMESERVER=10.0.2.3

boot_loader() {
    script_wait_line "$BOOT_PROMPT"
    if [ -n "$BOOT_COMMAND" ]; then
        script_send_line "$BOOT_COMMAND"
    else
        script_press_key ret
    fi
}

load_single_ramdisk() {
    local image
    image=$1

    script_wait_line "VFS: Insert ramdisk floppy and press ENTER"
    script_change_floppy "$image"
    script_press_key ret
}

load_two_ramdisks() {
    load_single_ramdisk ramdisk1.img
    script_wait_line "RHL: Insert ramdisk 2 floppy and press ENTER"
    script_change_floppy ramdisk2.img
    script_press_key ret
}

insert_boot_disk() {
    script_wait_string "Please insert your BOOT disk"
    script_change_floppy boot.img
    script_press_key ret
}

partition_disk() {
    local prompt
    prompt=$1

    script_wait_string "$prompt"
    script_press_key alt-f2
    script_wait_line "#"
    script_send_line "mount -t msdos /dev/hdb1 /mnt && /mnt/autoinst.d/diskpart.sh /dev/hda 64"
    script_wait_string "partitioned /dev/hda:"
    script_send_line "umount /mnt"
    script_press_key alt-f1
    script_wait_string "$prompt"
    script_press_key n
}

configure_network_common() {
    local order
    order=$1

    script_press_key y
    script_wait_string "What hostname have you selected for this computer?"
    script_send_line "$NET_HOSTNAME"
    script_wait_string "What domain name is this computer part of?"
    script_send_line "$NET_DOMAINNAME"
    script_wait_string "What is the fully qualified domain name (FQDN) of this computer?"
    script_press_key ret
    script_wait_string "What is the IP address of this computer?"
    script_send_line "$NET_IPADDR"
    if [ "$order" = "network-first" ]; then
        script_wait_string "What is the network address of this computer?"
        script_press_key ret
        script_wait_string "What is the netmask used by this computer?"
        script_press_key ret
    else
        script_wait_string "What is the netmask used by this computer?"
        script_press_key ret
        script_wait_string "What is the network address of this computer?"
        script_press_key ret
    fi
    script_wait_string "What is the broadcast address used by this computer?"
    script_press_key ret
    script_wait_string "Does this computer use a gateway?"
    script_press_key y
    script_wait_string "What is the IP address of the gateway used by this computer?"
    script_send_line "$NET_GATEWAY"
    script_wait_string "Does this computer use a nameserver?"
    script_press_key y
    script_wait_string "What is the IP address of the nameserver?"
    script_send_line "$NET_NAMESERVER"
    script_wait_string "Does this computer use another nameserver?"
    script_press_key n
    script_wait_string "Is this correct?"
    script_press_key y
}

format_root() {
    script_wait_string "Use the spacebar to select all partitions to format."
    script_press_key spc
    script_press_key ret
    script_wait_string "Are you absolutely certain that you want to format?"
    script_press_key y
}

configure_x11_common() {
    if [ "$#" -gt 0 ]; then
        script_wait_string "Which type of mouse do you have?" "$1"
    else
        script_wait_string "Which type of mouse do you have?"
    fi
    script_press_key p # selects ps2-bus
    script_press_key ret
    script_wait_string "Do you want to autoprobe?"
    script_press_key n
    script_wait_string "Pick a chipset."
    script_press_key ret # don't care; we'll overwrite this later
    script_wait_string "How much memory does your card have."
    script_press_key ret
    script_wait_string "Enter your clocks, separated by spaces."
    script_press_key ret
    script_wait_string "Please choose a monitor."
    script_press_key ret
}

confirm_network_configured() {
    script_wait_string "Networking has already been configured"
    script_press_key y
}

skip_modem_setup() {
    script_wait_string "No Modem"
    script_press_key ret
}

configure_system_clock() {
    local clock_prompt
    clock_prompt=$1

    script_wait_string "$clock_prompt"
    script_press_key ret
}

select_timezone() {
    script_wait_string "Pick a time zone."
    script_press_key ret
}

select_keymap() {
    script_wait_string "Select a keymap."
    script_press_key ret
}

install_lilo() {
    script_wait_string "Do you want to install LILO?"
    script_press_key y
    script_wait_string "Where do you want to install LILO?"
    script_press_key ret
    script_wait_string "Do you need to specify hardware parameters?"
    script_press_key n
    script_wait_string "Do you want to indicate another operating system"
    script_press_key n
}

skip_user_account() {
    script_wait_string "Do you want to create a user account?"
    script_press_key n
}

set_blank_root_password() {
    local confirm_twice
    confirm_twice=${1:-false}

    script_wait_string "You will now enter a password for the root user"
    script_press_key ret
    if [ "$confirm_twice" = "true" ]; then
        script_press_key ret # blank password
    fi
}

reboot_to_installed_system() {
    script_wait_string "Reboot now?"
    script_press_key y
    script_wait_string "Be sure to remove the boot floppy from your floppy drive!"
    script_set_boot c
    script_press_key ret
}

run_first_boot_autoconf() {
    script_run_autoconf
}
