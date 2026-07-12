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
    vga_wait -l "$BOOT_PROMPT"
    kb_type -n "$BOOT_COMMAND"
    if [ "$BOOT_SLEEP" != "0" ]; then
        sleep "$BOOT_SLEEP"
    fi
}

start_install() {
    boot_installer
    if [ "$COLOR_PROMPT" = "true" ]; then
        vga_wait "Are you using a color monitor?"
        kb_press f12 # selects yes
    fi
    vga_wait "Welcome to Red Hat Linux!"
    kb_press f12
    if [ "$LANGUAGE_PROMPT" = "true" ]; then
        vga_wait "Choose a Language"
        kb_press f12
    fi
    if [ "$KEYBOARD_EARLY" = "true" ]; then
        vga_wait "Keyboard Type"
        kb_press f12 # us
    fi
    if [ "$PCMCIA_PROMPT" = "true" ]; then
        vga_wait "Do you need PCMCIA support?"
        kb_press f12 # selects no
    fi
    vga_wait "Installation Method"
    kb_press f12 # selects CDROM
    vga_wait "$INSERT_CD_PROMPT"
    kb_press f12
    if [ "$CDROM_TYPE_PROMPT" = "true" ]; then
        vga_wait "What type of CDROM do you have?"
        kb_press f12 # selects IDE (ATAPI)
    fi
    vga_wait "Installation Path"
    kb_press f12 # selects Install
    vga_wait "Do you have any SCSI adapters?"
    kb_press f12 # selects no
}

partition_disk_helper() {
    local SHELL_PROMPT="bash#"

    kb_press alt-f2 # cli terminal
    fdisk_swap_root /dev/hda 64
    kb_press alt-f1 # installer terminal
}

partition_4x() {
    vga_wait "Partition Disks"
    partition_disk_helper
    vga_wait "Partition Disks"
    kb_press f12 # selects done
    vga_wait "Active Swap Space" # [sic]
    kb_press f12 # selects OK
    vga_wait "Select Root Partition"
    kb_press f12 # selects hda2
    vga_wait "You may now mount other partitions within your filesystem."
    kb_press down # selects /dev/hdb1
    kb_press ret # edits mount point
    vga_wait "Edit Mount Point"
    kb_type -n "/retro"
    kb_press f12 # next screen
    vga_wait "Format Partitions"
    kb_press spc # selects hda2
    kb_press f12 # next screen
}

select_components_40() {
    vga_wait "Components to Install"
    # Select a compact but useful package set.
    kb_press spc
    kb_repeat down 2
    kb_press spc
    kb_press down
    kb_press spc
    kb_repeat down 8
    kb_press spc
    kb_press down
    kb_press spc
    kb_press down
    kb_press spc
    kb_press down
    kb_press spc
    kb_press down
    kb_press spc
    kb_repeat down 5
    kb_press spc
    kb_press f12 # next screen
}

select_components_default() {
    vga_wait "Components to Install"
    # Keep the installer's default component selection.
    kb_press f12 # next screen
}

finish_components_selection() {
    vga_wait "Install log"
    kb_press f12
    if [ "$KEYBOARD_AFTER_PACKAGES" = "true" ]; then
        vga_wait "Configure Keyboard"
        kb_press f12
    fi
}

configure_x11_4x() {
    vga_wait "Configure Mouse"
    kb_press down
    kb_press down # select PS/2
    kb_press f12 # next screen
    vga_wait "Choose A Card"
    kb_repeat down "$X_CARD_DOWN" # scroll down to Cirrus Logic
    kb_press f12 # next screen
    vga_wait "Monitor Setup"
    kb_press down # highlight first non-custom
    kb_press "$MONITOR_SELECT_KEY" # select it
    vga_wait "Video Memory"
    kb_repeat down 4 # scroll down to 4096
    kb_press f12
    vga_wait "Clockchip Configuration"
    kb_press f12 # select No Clockchip Setting
    vga_wait "Select Video Modes"
    kb_press f12 # next screen
}

configure_x11_5x_common() {
    vga_wait "X Server : SVGA"
    kb_press f12 # next screen
    vga_wait "Monitor Setup"
    kb_press down # highlight first non-custom
    kb_press f12 # select it
    vga_wait "Screen Configuration"
    kb_press f12 # select Don't Probe
    vga_wait "Video Memory"
    kb_repeat down 4 # scroll down to 4096
    kb_press f12
    vga_wait "Clockchip Configuration"
    kb_press f12 # Don't Probe
    vga_wait "Select Video Modes"
    kb_press f12 # next screen
}

configure_network() {
    redhat_update_network_names
    vga_wait "Network Configuration"
    kb_press f12
    if [ "$POST_INSTALL_FLOW" = "51" ]; then
        vga_wait "Digital 21040 (Tulip)"
        kb_press f12
        vga_wait "Boot Protocol"
        kb_press f12
    fi
    vga_wait "Configure TCP/IP"
    kb_type -n "$NET_IPADDR"
    kb_repeat backspace 15 # erase default
    kb_type -n "$NET_NETMASK" # netmask
    kb_repeat backspace 15 # erase default
    kb_type -n "$NET_NETWORK" # network
    kb_repeat backspace 15 # erase default
    kb_type -n "$NET_BROADCAST" # broadcast
    kb_press f12
    vga_wait "Configure Network"
    kb_type -n "$NET_DOMAINNAME" # domain name
    kb_type -n "$NET_HOSTNAME" # hostname
    kb_repeat backspace 15 # erase default
    kb_type -n "$NET_GATEWAY" # gateway
    kb_repeat backspace 15 # erase default
    kb_type -n "$NET_NAMESERVER" # primary nameserver
    kb_press f12
}

configure_timezone() {
    vga_wait "$TIMEZONE_PROMPT"
    kb_press f12 # next screen
}

configure_late_keyboard() {
    if [ "$KEYBOARD_LATE" = "true" ]; then
        vga_wait "Configure Keyboard"
        kb_press f12
    fi
}

configure_services() {
    if [ "$POST_INSTALL_FLOW" = "50" ] || [ "$POST_INSTALL_FLOW" = "51" ]; then
        vga_wait "Services"
        kb_press f12 # next screen
    fi
}

skip_printer_setup() {
    if [ "$POST_INSTALL_FLOW" = "42" ]; then
        vga_wait "Add Printers"
        kb_press tab # select No
        kb_press ret # press No
    elif [ "$POST_INSTALL_FLOW" = "50" ] || [ "$POST_INSTALL_FLOW" = "51" ]; then
        vga_wait "Configure Printer"
        kb_press tab # select No
        kb_press ret # press No
    fi
}

set_root_password() {
    vga_wait "Root Password"
    kb_type -n "$ROOT_PASSWORD"
    kb_type -n "$ROOT_PASSWORD"
    kb_press f12
}

skip_bootdisk() {
    if [ "$BOOTDISK_PROMPT" = "true" ]; then
        vga_wait "Bootdisk"
        kb_press tab # select No
        kb_press ret # press No
    fi
}

install_lilo() {
    local count

    vga_wait "Lilo Installation"
    kb_press f12 # select Master Boot Record
    count=$LILO_EXTRA_F12
    while [ "$count" -gt 0 ]; do
        kb_press f12
        count=$((count - 1))
    done
    vga_wait "Bootable Partitions"
    kb_press down
    kb_press ret # edit dos partition
    kb_repeat backspace 3
    kb_press ret # close dialog
    kb_press f12 # next screen
}

reboot_and_postinst() {
    redhat_update_network_names
    vga_wait "Congratulations, installation is complete."
    script_set_boot c
    kb_press ret
    LOGIN_PROMPT="$NET_HOSTNAME login:"
    SHELL_PROMPT="[root@$NET_HOSTNAME /root]#"
    script_run_postinst "$ROOT_PASSWORD"
}
