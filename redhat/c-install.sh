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
    kb_send_line "$BOOT_COMMAND"
    if [ "$BOOT_SLEEP" != "0" ]; then
        sleep "$BOOT_SLEEP"
    fi
}

start_install() {
    boot_installer
    if [ "$COLOR_PROMPT" = "true" ]; then
        vga_wait "Are you using a color monitor?"
        kb_press_key f12 # selects yes
    fi
    vga_wait "Welcome to Red Hat Linux!"
    kb_press_key f12
    if [ "$LANGUAGE_PROMPT" = "true" ]; then
        vga_wait "Choose a Language"
        kb_press_key f12
    fi
    if [ "$KEYBOARD_EARLY" = "true" ]; then
        vga_wait "Keyboard Type"
        kb_press_key f12 # us
    fi
    if [ "$PCMCIA_PROMPT" = "true" ]; then
        vga_wait "Do you need PCMCIA support?"
        kb_press_key f12 # selects no
    fi
    vga_wait "Installation Method"
    kb_press_key f12 # selects CDROM
    vga_wait "$INSERT_CD_PROMPT"
    kb_press_key f12
    if [ "$CDROM_TYPE_PROMPT" = "true" ]; then
        vga_wait "What type of CDROM do you have?"
        kb_press_key f12 # selects IDE (ATAPI)
    fi
    vga_wait "Installation Path"
    kb_press_key f12 # selects Install
    vga_wait "Do you have any SCSI adapters?"
    kb_press_key f12 # selects no
}

partition_disk_helper() {
    local SHELL_PROMPT="bash#"

    kb_press_key alt-f2 # cli terminal
    serial_shell "mknod /dev/hda b 3 0"
    fdisk_swap_root /dev/hda 64
    kb_press_key alt-f1 # installer terminal
}

partition_4x() {
    vga_wait "Partition Disks"
    partition_disk_helper
    vga_wait "Partition Disks"
    kb_press_key f12 # selects done
    vga_wait "Active Swap Space" # [sic]
    kb_press_key f12 # selects OK
    vga_wait "Select Root Partition"
    kb_press_key f12 # selects hda2
    vga_wait "You may now mount other partitions within your filesystem."
    kb_press_key down # selects /dev/hdb1
    kb_press_key ret # edits mount point
    vga_wait "Edit Mount Point"
    kb_send_line "/retro"
    kb_press_key f12 # next screen
    vga_wait "Format Partitions"
    kb_press_key spc # selects hda2
    kb_press_key f12 # next screen
}

select_components_40() {
    vga_wait "Components to Install"
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
    vga_wait "Components to Install"
    # Keep the installer's default component selection.
    kb_press_key f12 # next screen
}

finish_components_selection() {
    vga_wait "Install log"
    kb_press_key f12
    if [ "$KEYBOARD_AFTER_PACKAGES" = "true" ]; then
        vga_wait "Configure Keyboard"
        kb_press_key f12
    fi
}

configure_x11_4x() {
    vga_wait "Configure Mouse"
    kb_press_key down
    kb_press_key down # select PS/2
    kb_press_key f12 # next screen
    vga_wait "Choose A Card"
    kb_press_key down "$X_CARD_DOWN" # scroll down to Cirrus Logic
    kb_press_key f12 # next screen
    vga_wait "Monitor Setup"
    kb_press_key down # highlight first non-custom
    kb_press_key "$MONITOR_SELECT_KEY" # select it
    vga_wait "Video Memory"
    kb_press_key down 4 # scroll down to 4096
    kb_press_key f12
    vga_wait "Clockchip Configuration"
    kb_press_key f12 # select No Clockchip Setting
    vga_wait "Select Video Modes"
    kb_press_key f12 # next screen
}

configure_x11_5x_common() {
    vga_wait "X Server : SVGA"
    kb_press_key f12 # next screen
    vga_wait "Monitor Setup"
    kb_press_key down # highlight first non-custom
    kb_press_key f12 # select it
    vga_wait "Screen Configuration"
    kb_press_key f12 # select Don't Probe
    vga_wait "Video Memory"
    kb_press_key down 4 # scroll down to 4096
    kb_press_key f12
    vga_wait "Clockchip Configuration"
    kb_press_key f12 # Don't Probe
    vga_wait "Select Video Modes"
    kb_press_key f12 # next screen
}

configure_network() {
    redhat_update_network_names
    vga_wait "Network Configuration"
    kb_press_key f12
    if [ "$POST_INSTALL_FLOW" = "51" ]; then
        vga_wait "Digital 21040 (Tulip)"
        kb_press_key f12
        vga_wait "Boot Protocol"
        kb_press_key f12
    fi
    vga_wait "Configure TCP/IP"
    kb_send_line "$NET_IPADDR"
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_NETMASK" # netmask
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_NETWORK" # network
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_BROADCAST" # broadcast
    kb_press_key f12
    vga_wait "Configure Network"
    kb_send_line "$NET_DOMAINNAME" # domain name
    kb_send_line "$NET_HOSTNAME" # hostname
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_GATEWAY" # gateway
    kb_press_key backspace 15 # erase default
    kb_send_line "$NET_NAMESERVER" # primary nameserver
    kb_press_key f12
}

configure_timezone() {
    vga_wait "$TIMEZONE_PROMPT"
    kb_press_key f12 # next screen
}

configure_late_keyboard() {
    if [ "$KEYBOARD_LATE" = "true" ]; then
        vga_wait "Configure Keyboard"
        kb_press_key f12
    fi
}

configure_services() {
    if [ "$POST_INSTALL_FLOW" = "50" ] || [ "$POST_INSTALL_FLOW" = "51" ]; then
        vga_wait "Services"
        kb_press_key f12 # next screen
    fi
}

skip_printer_setup() {
    if [ "$POST_INSTALL_FLOW" = "42" ]; then
        vga_wait "Add Printers"
        kb_press_key tab # select No
        kb_press_key ret # press No
    elif [ "$POST_INSTALL_FLOW" = "50" ] || [ "$POST_INSTALL_FLOW" = "51" ]; then
        vga_wait "Configure Printer"
        kb_press_key tab # select No
        kb_press_key ret # press No
    fi
}

set_root_password() {
    vga_wait "Root Password"
    kb_send_line "$ROOT_PASSWORD"
    kb_send_line "$ROOT_PASSWORD"
    kb_press_key f12
}

skip_bootdisk() {
    if [ "$BOOTDISK_PROMPT" = "true" ]; then
        vga_wait "Bootdisk"
        kb_press_key tab # select No
        kb_press_key ret # press No
    fi
}

install_lilo() {
    local count

    vga_wait "Lilo Installation"
    kb_press_key f12 # select Master Boot Record
    count=$LILO_EXTRA_F12
    while [ "$count" -gt 0 ]; do
        kb_press_key f12
        count=$((count - 1))
    done
    vga_wait "Bootable Partitions"
    kb_press_key down
    kb_press_key ret # edit dos partition
    kb_press_key backspace 3
    kb_press_key ret # close dialog
    kb_press_key f12 # next screen
}

reboot_and_postinst() {
    redhat_update_network_names
    vga_wait "Congratulations, installation is complete."
    script_set_boot c
    kb_press_key ret
    LOGIN_PROMPT="$NET_HOSTNAME login:"
    SHELL_PROMPT="[root@$NET_HOSTNAME /root]#"
    script_run_postinst "$ROOT_PASSWORD"
}
