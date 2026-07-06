# shellcheck shell=bash
#
# Shared QMP driver blocks for Red Hat's C-based text installer.
#
# This covers shared pieces of the UI-driven 4.0 through 5.1 installers.
# Release script.sh files should source it, override the defaults they need, and
# call the common blocks in installer prompt order.

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
    script_prompt "$BOOT_PROMPT" "$BOOT_COMMAND"
    if [ "$BOOT_SLEEP" != "0" ]; then
        sleep "$BOOT_SLEEP"
    fi
}

start_install() {
    boot_installer
    if [ "$COLOR_PROMPT" = "true" ]; then
        script_wait_string "Are you using a color monitor?"
        script_press_key f12 # selects yes
    fi
    script_wait_string "Welcome to Red Hat Linux!"
    script_press_key f12
    if [ "$LANGUAGE_PROMPT" = "true" ]; then
        script_wait_string "Choose a Language"
        script_press_key f12
    fi
    if [ "$KEYBOARD_EARLY" = "true" ]; then
        script_wait_string "Keyboard Type"
        script_press_key f12 # us
    fi
    if [ "$PCMCIA_PROMPT" = "true" ]; then
        script_wait_string "Do you need PCMCIA support?"
        script_press_key f12 # selects no
    fi
    script_wait_string "Installation Method"
    script_press_key f12 # selects CDROM
    script_wait_string "$INSERT_CD_PROMPT"
    script_press_key f12
    if [ "$CDROM_TYPE_PROMPT" = "true" ]; then
        script_wait_string "What type of CDROM do you have?"
        script_press_key f12 # selects IDE (ATAPI)
    fi
    script_wait_string "Installation Path"
    script_press_key f12 # selects Install
    script_wait_string "Do you have any SCSI adapters?"
    script_press_key f12 # selects no
}

partition_disk_helper() {
    local SHELL_PROMPT="bash#"

    script_press_key alt-f2 # cli terminal
    script_shell \
        "mkdir /mnt" \
        "mknod /dev/hda b 3 0" \
        "mknod /dev/hdb1 b 3 65" \
        "mount -t msdos /dev/hdb1 /mnt"
    script_partition_swaproot /dev/hda 64 /mnt
    script_shell "umount /mnt"
    script_press_key alt-f1 # installer terminal
}

partition_4x() {
    script_wait_string "Partition Disks"
    partition_disk_helper
    script_wait_string "Partition Disks"
    script_press_key f12 # selects done
    script_wait_string "Active Swap Space" # [sic]
    script_press_key f12 # selects OK
    script_wait_string "Select Root Partition"
    script_press_key f12 # selects hda2
    script_wait_string "You may now mount other partitions within your filesystem."
    script_press_key down # selects /dev/hdb1
    script_press_key ret # edits mount point
    script_wait_string "Edit Mount Point"
    script_send_line "/retro"
    script_press_key f12 # next screen
    script_wait_string "Format Partitions"
    script_press_key spc # selects hda2
    script_press_key f12 # next screen
}

select_components_40() {
    script_wait_string "Components to Install"
    # Manual selection:
    # [ ] C Development
    script_press_key spc
    # [X] C Development
    # [ ] Development Libraries
    script_press_key down 2
    # [ ] C++ Development
    script_press_key spc
    # [X] C++ Development
    script_press_key down
    # [ ] Print Server
    script_press_key spc
    # [X] Print Server
    # [ ] News Server
    # [ ] NFS Server
    # [ ] Networked Workstation
    # [ ] Anonymous FTP/Gopher Server
    # [ ] Web Server
    # [ ] Network Management Workstation
    # [ ] Dialup Workstation
    script_press_key down 8
    # [ ] Game Machine
    script_press_key spc
    # [X] Game Machine
    script_press_key down
    # [ ] Multimedia Machine
    script_press_key spc
    # [X] Multimedia Machine
    script_press_key down
    # [ ] X Window System
    script_press_key spc
    # [X] X Window System
    script_press_key down
    # [ ] X Development
    script_press_key spc
    # [X] X Development
    script_press_key down
    # [ ] X multimedia support
    script_press_key spc
    # [X] X multimedia support
    # [ ] TeX Document Formatting
    # [ ] Emacs
    # [ ] Emacs with X windows
    # [ ] DOS/Windows Connectivity
    script_press_key down 5
    # [ ] Extra Documentation
    script_press_key spc
    # [X] Extra Documentation
    # [ ] Everything
    script_press_key f12 # next screen
}

select_components_default() {
    script_wait_string "Components to Install"
    # Default selection:
    # 	[ ] Printer Support
    # 	[*] X Window System
    # 	[*] Mail/WWW/News Tools
    # 	[ ] DOS/Windows Connectivity
    # 	[*] File Managers
    # 	[ ] Graphics Manipulation
    # 	[ ] X Games
    # 	[ ] Console Games
    # 	[*] X multimedia support
    # 	[*] Console Multimedia
    # 	[ ] Print Server
    # 	[*] Networked Workstation
    # 	[*] Dialup Workstation
    # 	[ ] News Server
    # 	[ ] NFS Server
    # 	[ ] SMB (Samba) Connectivity
    # 	[ ] IPX/Netware(tm) Connectivity
    # 	[ ] Anonymous FTP/Gopher Server
    # 	[ ] Web Server
    # 	[ ] DNS Name Server
    # 	[ ] Postgres (SQL) Server
    # 	[ ] Network Management Workstation
    # 	[ ] TeX Document Formatting
    # 	[ ] Emacs
    # 	[ ] Emacs with X windows
    # 	[ ] C Development
    # 	[ ] Development Libraries
    # 	[ ] TeX Document Formatting
    # 	[ ] Emacs
    # 	[ ] Emacs with X windows
    # 	[ ] C Development
    # 	[ ] Development Libraries
    # 	[ ] C++ Development
    # 	[ ] X Development
    # 	[ ] Extra Documentation
    # 	[ ] Everything
    script_press_key f12 # next screen
}

finish_components_selection() {
    script_wait_string "Install log"
    script_press_key f12
    if [ "$KEYBOARD_AFTER_PACKAGES" = "true" ]; then
        script_wait_string "Configure Keyboard"
        script_press_key f12
    fi
}

configure_x11_4x() {
    script_wait_string "Configure Mouse"
    script_press_key down
    script_press_key down # select PS/2
    script_press_key f12 # next screen
    script_wait_string "Choose A Card"
    script_press_key down "$X_CARD_DOWN" # scroll down to Cirrus Logic
    script_press_key f12 # next screen
    script_wait_string "Monitor Setup"
    script_press_key down # highlight first non-custom
    script_press_key "$MONITOR_SELECT_KEY" # select it
    script_wait_string "Video Memory"
    script_press_key down 4 # scroll down to 4096
    script_press_key f12
    script_wait_string "Clockchip Configuration"
    script_press_key f12 # select No Clockchip Setting
    script_wait_string "Select Video Modes"
    script_press_key f12 # next screen
}

configure_x11_5x_common() {
    script_wait_string "X Server : SVGA"
    script_press_key f12 # next screen
    script_wait_string "Monitor Setup"
    script_press_key down # highlight first non-custom
    script_press_key f12 # select it
    script_wait_string "Screen Configuration"
    script_press_key f12 # select Don't Probe
    script_wait_string "Video Memory"
    script_press_key down 4 # scroll down to 4096
    script_press_key f12
    script_wait_string "Clockchip Configuration"
    script_press_key f12 # Don't Probe
    script_wait_string "Select Video Modes"
    script_press_key f12 # next screen
}

configure_network() {
    redhat_update_network_names
    script_wait_string "Network Configuration"
    script_press_key f12
    if [ "$POST_INSTALL_FLOW" = "51" ]; then
        script_wait_string "Digital 21040 (Tulip)"
        script_press_key f12
        script_wait_string "Boot Protocol"
        script_press_key f12
    fi
    script_wait_string "Configure TCP/IP"
    script_send_line "$NET_IPADDR"
    script_press_key backspace 15 # erase default
    script_send_line "$NET_NETMASK" # netmask
    script_press_key backspace 15 # erase default
    script_send_line "$NET_NETWORK" # network
    script_press_key backspace 15 # erase default
    script_send_line "$NET_BROADCAST" # broadcast
    script_press_key f12
    script_wait_string "Configure Network"
    script_send_line "$NET_DOMAINNAME" # domain name
    script_send_line "$NET_HOSTNAME" # hostname
    script_press_key backspace 15 # erase default
    script_send_line "$NET_GATEWAY" # gateway
    script_press_key backspace 15 # erase default
    script_send_line "$NET_NAMESERVER" # primary nameserver
    script_press_key f12
}

configure_timezone() {
    script_wait_string "$TIMEZONE_PROMPT"
    script_press_key f12 # next screen
}

configure_late_keyboard() {
    if [ "$KEYBOARD_LATE" = "true" ]; then
        script_wait_string "Configure Keyboard"
        script_press_key f12
    fi
}

configure_services() {
    if [ "$POST_INSTALL_FLOW" = "50" ] || [ "$POST_INSTALL_FLOW" = "51" ]; then
        script_wait_string "Services"
        script_press_key f12 # next screen
    fi
}

skip_printer_setup() {
    if [ "$POST_INSTALL_FLOW" = "42" ]; then
        script_wait_string "Add Printers"
        script_press_key tab # select No
        script_press_key ret # press No
    elif [ "$POST_INSTALL_FLOW" = "50" ] || [ "$POST_INSTALL_FLOW" = "51" ]; then
        script_wait_string "Configure Printer"
        script_press_key tab # select No
        script_press_key ret # press No
    fi
}

set_root_password() {
    script_wait_string "Root Password"
    script_send_line "$ROOT_PASSWORD"
    script_send_line "$ROOT_PASSWORD"
    script_press_key f12
}

skip_bootdisk() {
    if [ "$BOOTDISK_PROMPT" = "true" ]; then
        script_wait_string "Bootdisk"
        script_press_key tab # select No
        script_press_key ret # press No
    fi
}

install_lilo() {
    local count

    script_wait_string "Lilo Installation"
    script_press_key f12 # select Master Boot Record
    count=$LILO_EXTRA_F12
    while [ "$count" -gt 0 ]; do
        script_press_key f12
        count=$((count - 1))
    done
    script_wait_string "Bootable Partitions"
    script_press_key down
    script_press_key ret # edit dos partition
    script_press_key backspace 3
    script_press_key ret # close dialog
    script_press_key f12 # next screen
}

reboot_and_autoconf() {
    redhat_update_network_names
    script_wait_string "Congratulations, installation is complete."
    script_set_boot c
    script_press_key ret
    LOGIN_PROMPT="$NET_HOSTNAME login:"
    SHELL_PROMPT="[root@$NET_HOSTNAME /root]#"
    script_run_autoconf "$ROOT_PASSWORD"
}
