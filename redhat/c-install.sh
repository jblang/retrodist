# shellcheck shell=bash
# Shared driver blocks for Red Hat's C-based text installer.

BOOT_PROMPT="boot:"
BOOT_COMMAND=
BOOT_SLEEP=0
COLOR_PROMPT=true
LANGUAGE_PROMPT=false
KEYBOARD_EARLY=false
KEYBOARD_AFTER_PACKAGES=false
KEYBOARD_LATE=false
PCMCIA_PROMPT=true
CDROM_TYPE_PROMPT=true
INSERT_CD_PROMPT="Insert your Red Hat CD into your CD drive"
POST_INSTALL_FLOW=4x
X_CARD_DOWN=66
MONITOR_SELECT_KEY=ret
TIMEZONE_PROMPT="Configure Timezone"
LILO_EXTRA_F12=0
BOOTDISK_PROMPT=false
ROOT_PASSWORD=password

NET_IPADDR=10.0.2.15
NET_NETMASK=255.255.255.0
NET_NETWORK=10.0.2.0
NET_BROADCAST=10.0.2.255
NET_HOSTNAME=redhat
NET_DOMAINNAME=retro.net
NET_FQDN=$NET_HOSTNAME.$NET_DOMAINNAME
NET_GATEWAY=10.0.2.2
NET_NAMESERVER=10.0.2.3

redhat_update_network_names() {
    NET_FQDN=$NET_HOSTNAME.$NET_DOMAINNAME
}

boot_installer() {
    screen_wait -l "$BOOT_PROMPT"
    kb_send_line "$BOOT_COMMAND"
    if [ "$BOOT_SLEEP" != "0" ]; then
        sleep "$BOOT_SLEEP"
    fi
}

start_install() {
    boot_installer
    if [ "$COLOR_PROMPT" = "true" ]; then
        screen_wait "Are you using a color monitor?"
        kb_press_key f12 # selects yes
    fi
    screen_wait "Welcome to Red Hat Linux!"
    kb_press_key f12
    if [ "$LANGUAGE_PROMPT" = "true" ]; then
        screen_wait "Choose a Language"
        kb_press_key f12
    fi
    if [ "$KEYBOARD_EARLY" = "true" ]; then
        screen_wait "Keyboard Type"
        kb_press_key f12 # us
    fi
    if [ "$PCMCIA_PROMPT" = "true" ]; then
        screen_wait "Do you need PCMCIA support?"
        kb_press_key f12 # selects no
    fi
    screen_wait "Installation Method"
    kb_press_key f12 # selects CDROM
    screen_wait "$INSERT_CD_PROMPT"
    kb_press_key f12
    if [ "$CDROM_TYPE_PROMPT" = "true" ]; then
        screen_wait "What type of CDROM do you have?"
        kb_press_key f12 # selects IDE (ATAPI)
    fi
    screen_wait "Installation Path"
    kb_press_key f12 # selects Install
    screen_wait "Do you have any SCSI adapters?"
    kb_press_key f12 # selects no
}

partition_disk_helper() {
    local SHELL_PROMPT="bash#"

    kb_press_key alt-f2 # cli terminal
    serial_shell "mknod /dev/hda b 3 0"
    script_fdisk /dev/hda 64
    kb_press_key alt-f1 # installer terminal
}

partition_4x() {
    screen_wait "Partition Disks"
    partition_disk_helper
    screen_wait "Partition Disks"
    kb_press_key f12 # selects done
    screen_wait "Active Swap Space" # [sic]
    kb_press_key f12 # selects OK
    screen_wait "Select Root Partition"
    kb_press_key f12 # selects hda2
    screen_wait "You may now mount other partitions within your filesystem."
    kb_press_key down # selects /dev/hdb1
    kb_press_key ret # edits mount point
    screen_wait "Edit Mount Point"
    kb_send_line "/retro"
    kb_press_key f12 # next screen
    screen_wait "Format Partitions"
    kb_press_key spc # selects hda2
    kb_press_key f12 # next screen
}

select_components_40() {
    screen_wait "Components to Install"
    # Select a compact but useful package set.
    kb_press_key spc
    kb_press_key down 2
    kb_press_key spc
    kb_press_key down
    kb_press_key spc
    kb_press_key down 8
    kb_press_key spc
    kb_press_key down
    kb_press_key spc
    kb_press_key down
    kb_press_key spc
    kb_press_key down
    kb_press_key spc
    kb_press_key down
    kb_press_key spc
    kb_press_key down 5
    kb_press_key spc
    kb_press_key f12 # next screen
}

select_components_default() {
    screen_wait "Components to Install"
    # Keep the installer's default component selection.
    kb_press_key f12 # next screen
}

finish_components_selection() {
    screen_wait "Install log"
    kb_press_key f12
    if [ "$KEYBOARD_AFTER_PACKAGES" = "true" ]; then
        screen_wait "Configure Keyboard"
        kb_press_key f12
    fi
}

configure_x11_4x() {
    screen_wait "Configure Mouse"
    kb_press_key down
    kb_press_key down # select PS/2
    kb_press_key f12 # next screen
    screen_wait "Choose A Card"
    kb_press_key down "$X_CARD_DOWN" # scroll down to Cirrus Logic
    kb_press_key f12 # next screen
    screen_wait "Monitor Setup"
    kb_press_key down # highlight first non-custom
    kb_press_key "$MONITOR_SELECT_KEY" # select it
    screen_wait "Video Memory"
    kb_press_key down 4 # scroll down to 4096
    kb_press_key f12
    screen_wait "Clockchip Configuration"
    kb_press_key f12 # select No Clockchip Setting
    screen_wait "Select Video Modes"
    kb_press_key f12 # next screen
}

configure_x11_5x_common() {
    screen_wait "X Server : SVGA"
    kb_press_key f12 # next screen
    screen_wait "Monitor Setup"
    kb_press_key down # highlight first non-custom
    kb_press_key f12 # select it
    screen_wait "Screen Configuration"
    kb_press_key f12 # select Don't Probe
    screen_wait "Video Memory"
    kb_press_key down 4 # scroll down to 4096
    kb_press_key f12
    screen_wait "Clockchip Configuration"
    kb_press_key f12 # Don't Probe
    screen_wait "Select Video Modes"
    kb_press_key f12 # next screen
}

configure_network() {
    redhat_update_network_names
    screen_wait "Network Configuration"
    kb_press_key f12
    if [ "$POST_INSTALL_FLOW" = "51" ]; then
        screen_wait "Digital 21040 (Tulip)"
        kb_press_key f12
        screen_wait "Boot Protocol"
        kb_press_key f12
    fi
    screen_wait "Configure TCP/IP"
    kb_send_line "$NET_IPADDR"
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_NETMASK" # netmask
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_NETWORK" # network
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_BROADCAST" # broadcast
    kb_press_key f12
    screen_wait "Configure Network"
    kb_send_line "$NET_DOMAINNAME" # domain name
    kb_send_line "$NET_HOSTNAME" # hostname
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_GATEWAY" # gateway
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_NAMESERVER" # primary nameserver
    kb_press_key f12
}

configure_timezone() {
    screen_wait "$TIMEZONE_PROMPT"
    kb_press_key f12 # next screen
}

configure_late_keyboard() {
    if [ "$KEYBOARD_LATE" = "true" ]; then
        screen_wait "Configure Keyboard"
        kb_press_key f12
    fi
}

configure_services() {
    if [ "$POST_INSTALL_FLOW" = "50" ] || [ "$POST_INSTALL_FLOW" = "51" ]; then
        screen_wait "Services"
        kb_press_key f12 # next screen
    fi
}

skip_printer_setup() {
    if [ "$POST_INSTALL_FLOW" = "42" ]; then
        screen_wait "Add Printers"
        kb_press_key tab # select No
        kb_press_key ret # press No
    elif [ "$POST_INSTALL_FLOW" = "50" ] || [ "$POST_INSTALL_FLOW" = "51" ]; then
        screen_wait "Configure Printer"
        kb_press_key tab # select No
        kb_press_key ret # press No
    fi
}

set_root_password() {
    screen_wait "Root Password"
    kb_send_line "$ROOT_PASSWORD"
    kb_send_line "$ROOT_PASSWORD"
    kb_press_key f12
}

skip_bootdisk() {
    if [ "$BOOTDISK_PROMPT" = "true" ]; then
        screen_wait "Bootdisk"
        kb_press_key tab # select No
        kb_press_key ret # press No
    fi
}

install_lilo() {
    local count

    screen_wait "Lilo Installation"
    kb_press_key f12 # select Master Boot Record
    count=$LILO_EXTRA_F12
    while [ "$count" -gt 0 ]; do
        kb_press_key f12
        count=$((count - 1))
    done
    screen_wait "Bootable Partitions"
    kb_press_key down
    kb_press_key ret # edit dos partition
    kb_press_key backspace 3
    kb_press_key ret # close dialog
    kb_press_key f12 # next screen
}

reboot_and_autoconf() {
    redhat_update_network_names
    screen_wait "Congratulations, installation is complete."
    script_set_boot c
    kb_press_key ret
    LOGIN_PROMPT="$NET_HOSTNAME login:"
    SHELL_PROMPT="[root@$NET_HOSTNAME /root]#"
    script_run_autoconf "$ROOT_PASSWORD"
}
