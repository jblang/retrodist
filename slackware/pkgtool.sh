# shellcheck shell=bash
# Shared driver for Slackware 1.1.2-9.0 dialog-based setup.

SETUP_HOSTNAME=slackware

TARGET_DISK=/dev/hda
SWAP_MB=64

# QEMU exposes qemu.d/fat here; Slackware mounts it at FAT_MOUNT.
FAT_PARTITION=/dev/hdb1
FAT_MOUNT=/retro

SETUP_SOURCE=/dev/hdc

LINUX_PARTITION=/dev/hda2
LINUX_PARTITION_NAME=linux

# LILO frame buffer console mode; only offered by kernels with fbcon support.
LILO_FRAMEBUFFER=standard

# Custom tagfiles let path prompting mode work from read-only media.
INSTALL_MODE=
TAGFILE_PATH=/retro/tagfiles

MODEM_SPEED=38400
SENDMAIL_MODE=SMTP

# SERIES SELECTION is a checklist, so each set must be its own quoted token.
#PACKAGE_SETS='"A" "AP" "D" "E" "F" "I" "IV" "N" "OOP" "Q" "T" "TCL" "X" "XAP" "XD" "XV" "Y"'
PACKAGE_SETS='"A" "AP" "N" "X" "XAP"'

# Network configuration:
NET_HOSTNAME=darkstar
NET_DOMAINNAME=retro.net
NET_IPADDR=10.0.2.15
NET_NETWORK=10.0.2.0
NET_BROADCAST=10.0.2.255
NET_GATEWAY=10.0.2.2
NET_NETMASK=255.255.255.0
NET_NAMESERVER=10.0.2.3

TIMEZONE=UTC

# 7.0+ runs xwmconfig with the installed dialog binary, which bypasses the
# serial interposer; acknowledge its console screen after timezone setup.
XWMCONFIG=false

# Log in to the installer environment as root.
pkgtool_login_as_root() {
    screen_wait -l "$SETUP_HOSTNAME login:"
    kb_send_line root
}

# Perform pre-setup steps and then start the setup script
pkgtool_start_setup() {
    serial_shell_start || return 1
    serial_shell_send "mkdir -p $FAT_MOUNT" || return 1
    serial_shell_send "mount -t msdos $FAT_PARTITION $FAT_MOUNT" || return 1
    # Delete rather than rename: keeping the 64KB dialog binary on the nearly
    # full install ramdisk starves setup's /tmp result files (ENOSPC).
    serial_shell_send "rm /bin/dialog" || return 1
    serial_shell_send "cp $FAT_MOUNT/autoinst.d/dialog.sh /bin/dialog" || return 1
    serial_shell_send --no-wait "fdisk $TARGET_DISK" || return 1
    script_fdisk_partitions "$SWAP_MB" || return 1
    serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1
    serial_shell_exit || return 1
    kb_send_line "setup" || return 1
}

# Choose a step from the Slackware Linux Setup main menu.
pkgtool_setup_step() {
    dialog_answer menu -r "Slackware(96)? Linux Setup \(version .*\)" "$1"
}

# Select verbose install mode from the setup main menu when the release exposes
# it there. Slackware 3.0 otherwise stays in QUICK mode and ignores tagfiles.
pkgtool_select_install_mode() {
    if [ -z "$INSTALL_MODE" ]; then
        pkgtool_setup_step ADDSWAP
        return
    fi
    pkgtool_setup_step QUICK
    dialog_answer menu "CHANGE INSTALL MODE" "$INSTALL_MODE"
    pkgtool_setup_step ADDSWAP
}

# Install the detected swap partition and let setup activate it.
pkgtool_enable_swap() {
    dialog_answer -l "swap partition" \
        yesno "SWAP SPACE DETECTED" yes \
        msgbox "MKSWAP WARNING" ok \
        yesno "USE MKSWAP?" yes \
        yesno "ACTIVATE SWAP SPACE?" yes \
        msgbox "SWAP SPACE CONFIGURED" ok \
        -x yesno "CONTINUE WITH INSTALLATION?" yes
}

# Format root, answering only the optional screens this setup version raises.
pkgtool_format_root() {
    dialog_answer -l "root partition" \
        menu "Select Linux installation partition:" "$LINUX_PARTITION" \
        msgbox "Using this partition for Linux:" ok \
        menu -r "(CHOOSE LINUX FILESYSTEM|SELECT FILESYSTEM FOR .*)" ext2 \
        menu -r "FORMAT PARTITION( .*)?" Format \
        menu -r "SELECT INODE DENSITY( .*)?" 4096 \
        msgbox "DONE ADDING LINUX PARTITIONS TO /etc/fstab" ok \
        -x yesno "DOS AND OS/2 PARTITION SETUP" yes \
        -x yesno -r "FAT/FAT32(/HPFS)? PARTITIONS DETECTED" yes
}

# Mount the FAT staging partition so it's visible from the installed system.
pkgtool_mount_fat() {
    dialog_answer -l "fat partition" \
        inputbox "CHOOSE PARTITION" "$FAT_PARTITION" \
        menu "CHOOSE PARTITION" "$FAT_PARTITION" \
        menu "SELECT PARTITION TO ADD TO /etc/fstab" "$FAT_PARTITION" \
        inputbox "SELECT MOUNT POINT" "$FAT_MOUNT" \
        inputbox -r "PICK MOUNT POINT FOR .*" "$FAT_MOUNT" \
        msgbox "CURRENT DOS/HPFS PARTITION STATUS" ok \
        msgbox -r "DONE ADDING FAT/FAT32(/HPFS)? PARTITIONS" ok \
        inputbox "CHOOSE PARTITION" q \
        -x yesno "CONTINUE?" yes
}

pkgtool_select_manual_cdrom() {
    dialog_answer menu -r "$1" manual
}

# Answer whichever CD-ROM device menu this version raises with SETUP_SOURCE.
pkgtool_select_cdrom_device() {
    dialog_answer menu -r "$1" "$SETUP_SOURCE"
}

# Decline further source prompts once setup reports the drive it is using.
pkgtool_keep_cdrom() {
    dialog_answer yesno -r "$1" no
}

# Choose the normal installation method from the CD.
pkgtool_select_install_type() {
    dialog_answer menu -r "$1" slakware
}

# Select the IDE CD-ROM drive as the Slackware package source. Versions differ
# in which detection screens appear (3.6 auto-scans and skips straight to the
# installation type menu), so one dispatch answers whichever subset shows up
# and the installation type menu terminates it.
pkgtool_select_source() {
	if [[ $SETUP_SOURCE == "/dev/hdc" ]]; then
		dialog_answer -l "source selection" \
			menu "SOURCE MEDIA SELECTION" -d "CD-ROM" \
			menu "Install from the Slackware CD-ROM" -d -r "(IDE.*CD drives|ATAPI/IDE CD drives)" \
			menu "SCAN FOR CD-ROM DRIVE?" -f pkgtool_select_manual_cdrom \
			menu "SELECT IDE DEVICE" -f pkgtool_select_cdrom_device \
			menu "MANUAL CD-ROM DEVICE SELECTION" -f pkgtool_select_cdrom_device \
			yesno -r "USING CD-ROM DRIVE:.*" -f pkgtool_keep_cdrom \
			-x menu "Pick your installation method" -f pkgtool_select_install_type \
			-x menu "CHOOSE INSTALLATION TYPE" -f pkgtool_select_install_type \
			yesno "CONTINUE?"
	elif [[ $SETUP_SOURCE == "$FAT_PARTITION" ]]; then
		dialog_answer menu "SOURCE MEDIA SELECTION" 4 # Hard drive partitition
		dialog_answer inputbox "INSTALL FROM THE CURRENT FILESYSTEM" "$FAT_MOUNT/packages"
	else
		log_warn "Manually select your source; automatic installation will resume afterwards"
	fi
    dialog_answer yesno "CONTINUE?" yes
}

# Select the Slackware package sets to install, using custom tagfiles.
pkgtool_select_sets() {
    dialog_answer \
        checklist -r "(PACKAGE |SOFTWARE )?SERIES SELECTION" "$PACKAGE_SETS" \
        -x yesno "CONTINUE?" yes
    if [ -n "$TAGFILE_PATH" ]; then
        dialog_answer menu "SELECT PROMPTING MODE" -d "custom path"
        dialog_answer inputbox "PROVIDE A CUSTOM PATH TO YOUR TAGFILES" "$TAGFILE_PATH"
    else
        dialog_answer menu "SELECT PROMPTING MODE" -d "default tagfiles"
    fi
}

# The functions below are dialog_answer -f handlers for post-install
# configuration.

# Install LILO to the target disk MBR, handling the optional append= screen.
pkgtool_install_lilo() {
    local lilo_title="LILO INSTALLATION"

    case "$1" in
    "INSTALL LILO")
        dialog_answer menu "$1" expert
        lilo_title="EXPERT LILO INSTALLATION"
        dialog_answer menu "$lilo_title" Begin
        ;;
    *)
        lilo_title=$1
        dialog_answer menu "$lilo_title" Begin
        ;;
    esac
    dialog_answer \
        inputbox -r "OPTIONAL (LILO )?append=.* LINE" "" \
        menu "CONFIGURE LILO TO USE FRAME BUFFER CONSOLE?" "$LILO_FRAMEBUFFER" \
        menu "SELECT LILO TARGET LOCATION"
    dialog_answer menu "SELECT LILO TARGET LOCATION" MBR
    dialog_answer \
        inputbox "CONFIRM LOCATION TO INSTALL LILO" "$TARGET_DISK" \
        -x menu -r "CHOOSE LILO (DELAY|TIMEOUT)" None
    dialog_answer menu "$lilo_title" Linux
    dialog_answer inputbox "SELECT LINUX PARTITION" "$LINUX_PARTITION"
    dialog_answer inputbox "SELECT PARTITION NAME" "$LINUX_PARTITION_NAME"
    dialog_answer menu "$lilo_title" Install
}

# Configure TCP/IP with NET_* values; prompt order varies by version. 9.0
# confirms with an inputmenu; an empty answer accepts the entered settings.
pkgtool_configure_network() {
    dialog_answer yesno "$1" yes
    dialog_answer -l "network configuration" \
        msgbox "NETWORK CONFIGURATION" "" \
        inputbox "ENTER HOSTNAME" "$NET_HOSTNAME" \
        inputbox -r "ENTER DOMAINNAME( FOR .*)?" "$NET_DOMAINNAME" \
        yesno "LOOPBACK ONLY?" no \
        menu -r "SETUP IP (ADDRESS )?FOR .*" "static IP" \
        inputbox -r "ENTER (LOCAL IP ADDRESS|IP ADDRESS FOR .*)" "$NET_IPADDR" \
        inputbox "ENTER NETWORK ADDRESS" "$NET_NETWORK" \
        inputbox "ENTER BROADCAST ADDRESS" "$NET_BROADCAST" \
        inputbox "ENTER GATEWAY ADDRESS" "$NET_GATEWAY" \
        inputbox -r "ENTER NETMASK( .*)?" "$NET_NETMASK" \
        yesno "USE A NAMESERVER?" yes \
        inputbox "SELECT NAMESERVER" "$NET_NAMESERVER" \
        menu "PROBE FOR NETWORK CARD?" probe \
        msgbox "CARD DETECTED" ok \
        -x msgbox "NETWORK SETUP COMPLETE" ok \
        -x yesno "NETWORK SETUP COMPLETE" yes \
        -x inputmenu "CONFIRM NETWORK SETUP" ""
}

# Install a sendmail.cf suited to a networked host with a nameserver.
pkgtool_configure_sendmail() {
    dialog_answer menu "$1" "$SENDMAIL_MODE"
	# this has to be handled here to avoid breaking the configuration flow
    pkgtool_xwmconfig
}

# Accept the first window manager on the console. 7.0+ runs xwmconfig with the
# installed dialog binary, which bypasses the serial interposer. Its position
# varies so peek briefly at both points and stop checking once answered.
pkgtool_xwmconfig() {
    if [ "$XWMCONFIG" = true ]; then
        if screen_wait -t 1 "SELECT DEFAULT WINDOW MANAGER FOR X"; then
            kb_press_key spc
            kb_press_key ret
            XWMCONFIG=false
        fi
    fi
}

# Configure the installed system timezone.
pkgtool_configure_timezone() {
    dialog_answer menu "$1" "$TIMEZONE"
    pkgtool_xwmconfig
}

# Answer post-install configuration screens until SETUP COMPLETE appears.
pkgtool_configure() {
    dialog_answer -l "system configuration" \
        yesno "CONFIGURE YOUR SYSTEM?" yes \
        menu "MAKE BOOTDISK" continue \
        yesno "MAKE BOOT DISK?" no \
        msgbox "SKIPPED BOOT DISK CREATION" ok \
        yesno "MODEM CONFIGURATION" no \
        menu "MODEM CONFIGURATION" "no modem" \
        yesno "MOUSE CONFIGURATION" no \
        menu "MOUSE CONFIGURATION" ps2 \
        yesno "CONFIGURE CD-ROM?" no \
        yesno "SCREEN FONT CONFIGURATION" no \
        yesno "CONSOLE FONT CONFIGURATION" no \
        yesno "FTAPE CONFIGURATION" no \
        menu "SET YOUR MODEM SPEED" "$MODEM_SPEED" \
        menu "INSTALL LINUX KERNEL" skip \
        menu "INSTALL LILO" -f pkgtool_install_lilo \
        menu "LILO INSTALLATION" -f pkgtool_install_lilo \
        yesno "CONFIGURE NETWORK?" -f pkgtool_configure_network \
        yesno "GPM CONFIGURATION" no \
        yesno "ENABLE HOTPLUG SUBSYSTEM AT BOOT?" no \
        yesno "SELECTION 1.5 CONFIGURATION" no \
        menu "SENDMAIL CONFIGURATION" -f pkgtool_configure_sendmail \
        menu "HARDWARE CLOCK SET TO UTC?" YES \
        menu "TIMEZONE CONFIGURATION" -f pkgtool_configure_timezone \
        yesno "WARNING: NO ROOT PASSWORD DETECTED" no \
        -x msgbox "SETUP COMPLETE" ok
}

# Exit setup after configuration is complete.
pkgtool_finish() {
    pkgtool_setup_step EXIT
}

# Reboot from the installed hard disk.
pkgtool_reboot() {
    script_set_boot c
    kb_press_key ctrl-alt-delete
}

# Run the staged first-boot autoconfiguration script. AUTOCONF_PROMPT
# overrides the first-boot root prompt; 8.1+ uses root@HOSTNAME:~#.
pkgtool_autoconf() {
    local prompt="${AUTOCONF_PROMPT:-$NET_HOSTNAME:~#}"

    screen_wait -l "$NET_HOSTNAME login:"
    kb_send_line root
    screen_wait -l "$prompt"
    kb_send_line "$FAT_MOUNT/autoinst.d/autoconf.sh"
}

# Set up target partitions and pick the source in this version's order.
pkgtool_target_source() {
    pkgtool_format_root
    pkgtool_mount_fat
    pkgtool_select_source
}

# Drive the full dialog setup install sequence.
pkgtool_setup() {
    pkgtool_login_as_root
    pkgtool_start_setup
    pkgtool_select_install_mode
    pkgtool_enable_swap
    pkgtool_target_source
    pkgtool_select_sets
	log_write "🏗️ " "Package installation in progress..."
    pkgtool_configure
    pkgtool_finish
    pkgtool_reboot
    pkgtool_autoconf
}
