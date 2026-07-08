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
dialog_login_as_root() {
    screen_wait -l "$SETUP_HOSTNAME login:"
    kb_send_line root
}

# Perform pre-setup steps and then start the setup script
dialog_start_setup() {
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
dialog_setup_step() {
    dialog_answer -r "Slackware(96)? Linux Setup \(version .*\)" menu "$1"
}

# Select verbose install mode from the setup main menu when the release exposes
# it there. Slackware 3.0 otherwise stays in QUICK mode and ignores tagfiles.
dialog_select_install_mode() {
    if [ -z "$INSTALL_MODE" ]; then
        dialog_setup_step ADDSWAP
        return
    fi
    dialog_setup_step QUICK
    dialog_answer "CHANGE INSTALL MODE" menu "$INSTALL_MODE"
    dialog_setup_step ADDSWAP
}

# Install the detected swap partition and let setup activate it.
dialog_enable_swap() {
    dialog_answer_any \
        yesno "SWAP SPACE DETECTED" yes \
        msgbox "MKSWAP WARNING" ok \
        yesno "USE MKSWAP?" yes \
        yesno "ACTIVATE SWAP SPACE?" yes \
        msgbox "SWAP SPACE CONFIGURED" ok \
        -t yesno "CONTINUE WITH INSTALLATION?" yes
}

# Format root, answering only the optional screens this setup version raises.
dialog_format_root() {
    dialog_answer_any -r \
        menu "Select Linux installation partition:" "$LINUX_PARTITION" \
        msgbox "Using this partition for Linux:" ok \
        menu "(CHOOSE LINUX FILESYSTEM|SELECT FILESYSTEM FOR .*)" ext2 \
        menu "FORMAT PARTITION( .*)?" Format \
        menu "SELECT INODE DENSITY( .*)?" 4096 \
        msgbox "DONE ADDING LINUX PARTITIONS TO /etc/fstab" ok \
        -t yesno "DOS AND OS/2 PARTITION SETUP" yes \
        -t yesno "FAT/FAT32(/HPFS)? PARTITIONS DETECTED" yes
}

# Mount the FAT staging partition so it's visible from the installed system.
dialog_mount_fat() {
    dialog_answer_any -r \
        inputbox "CHOOSE PARTITION" "$FAT_PARTITION" \
        menu "CHOOSE PARTITION" "$FAT_PARTITION" \
        menu "SELECT PARTITION TO ADD TO /etc/fstab" "$FAT_PARTITION" \
        inputbox "SELECT MOUNT POINT" "$FAT_MOUNT" \
        inputbox "PICK MOUNT POINT FOR .*" "$FAT_MOUNT" \
        msgbox "CURRENT DOS/HPFS PARTITION STATUS" ok \
        msgbox "DONE ADDING FAT/FAT32(/HPFS)? PARTITIONS" ok \
        inputbox "CHOOSE PARTITION" q \
        -t yesno "CONTINUE\?" yes
}

# Choose CD-ROM as the install media; the item number varies by version.
dialog_select_media() {
    dialog_menu_text "$1" "CD-ROM"
}

dialog_select_cdrom_type() {
    dialog_menu_text -r "$1" "(IDE.*CD drives|ATAPI/IDE CD drives)"
}

dialog_select_manual_cdrom() {
    dialog_answer -r "$1" menu manual
}

# Answer whichever CD-ROM device menu this version raises with SETUP_SOURCE.
dialog_select_cdrom_device() {
    dialog_answer -r "$1" menu "$SETUP_SOURCE"
}

# Decline further source prompts once setup reports the drive it is using.
dialog_keep_cdrom() {
    dialog_answer -r "$1" yesno no
}

# Choose the normal installation method from the CD.
dialog_select_install_type() {
    dialog_answer -r "$1" menu slakware
}

# Select the IDE CD-ROM drive as the Slackware package source. Versions differ
# in which detection screens appear (3.6 auto-scans and skips straight to the
# installation type menu), so one dispatch answers whichever subset shows up
# and the installation type menu terminates it.
dialog_select_source() {
	if [[ $SETUP_SOURCE == "/dev/hdc" ]]; then
		dialog_case -r \
			menu "SOURCE MEDIA SELECTION" dialog_select_media \
			menu "Install from the Slackware CD-ROM" dialog_select_cdrom_type \
			menu "SCAN FOR CD-ROM DRIVE[?]" dialog_select_manual_cdrom \
			menu "SELECT IDE DEVICE" dialog_select_cdrom_device \
			menu "MANUAL CD-ROM DEVICE SELECTION" dialog_select_cdrom_device \
			yesno "USING CD-ROM DRIVE:" dialog_keep_cdrom \
			-t menu "Pick your installation method" dialog_select_install_type \
			-t menu "CHOOSE INSTALLATION TYPE" dialog_select_install_type \
			yesno "CONTINUE\?"
	elif [[ $SETUP_SOURCE == "$FAT_PARTITION" ]]; then
		dialog_answer "SOURCE MEDIA SELECTION" menu 4 # Hard drive partitition
		dialog_answer "INSTALL FROM THE CURRENT FILESYSTEM" inputbox "$FAT_MOUNT/packages"
	else
		log_warn "Manually select your source; automatic installation will resume afterwards"
	fi
    dialog_yes "CONTINUE?"
}

# Select the Slackware package sets to install, using custom tagfiles.
dialog_select_sets() {
    dialog_answer_any -r \
        checklist "(PACKAGE |SOFTWARE )?SERIES SELECTION" "$PACKAGE_SETS" \
        yesno "CONTINUE[?]"
    dialog_yes "CONTINUE?"
    if [ -n "$TAGFILE_PATH" ]; then
        dialog_menu_text "SELECT PROMPTING MODE" "custom path"
        dialog_answer "PROVIDE A CUSTOM PATH TO YOUR TAGFILES" inputbox "$TAGFILE_PATH"
    else
        dialog_menu_text "SELECT PROMPTING MODE" "default tagfiles"
    fi
}

# The functions below are dialog_case handlers for post-install configuration.

# Skip creating an installer boot disk.
dialog_skip_boot_disk() {
    dialog_answer "$1" menu continue
}

# Answer the modem speed selection with MODEM_SPEED.
dialog_set_modem_speed() {
    dialog_answer "$1" menu "$MODEM_SPEED"
}

dialog_skip_modem() {
    dialog_answer "$1" menu "no modem"
}

dialog_configure_mouse() {
    dialog_answer "$1" menu ps2
}

# Keep the kernel installed from the selected package set.
dialog_skip_kernel_install() {
    dialog_answer "$1" menu skip
}

# Install LILO to the target disk MBR, handling the optional append= screen.
dialog_install_lilo() {
    local lilo_title="LILO INSTALLATION"

    case "$1" in
    "INSTALL LILO")
        dialog_answer "$1" menu expert
        lilo_title="EXPERT LILO INSTALLATION"
        dialog_answer "$lilo_title" menu Begin
        ;;
    *)
        lilo_title=$1
        dialog_answer "$lilo_title" menu Begin
        ;;
    esac
    dialog_answer_any -r \
        inputbox "OPTIONAL (LILO )?append=.* LINE" "" \
        menu "CONFIGURE LILO TO USE FRAME BUFFER CONSOLE[?]" "$LILO_FRAMEBUFFER" \
        menu "SELECT LILO TARGET LOCATION"
    dialog_answer "SELECT LILO TARGET LOCATION" menu MBR
    dialog_answer_any -r \
        inputbox "CONFIRM LOCATION TO INSTALL LILO" "$TARGET_DISK" \
        -t menu "CHOOSE LILO (DELAY|TIMEOUT)" None
    dialog_answer "$lilo_title" menu Linux
    dialog_answer "SELECT LINUX PARTITION" inputbox "$LINUX_PARTITION"
    dialog_answer "SELECT PARTITION NAME" inputbox "$LINUX_PARTITION_NAME"
    dialog_answer "$lilo_title" menu Install
}

# Configure TCP/IP with NET_* values; prompt order varies by version. 9.0
# confirms with an inputmenu; an empty answer accepts the entered settings.
dialog_configure_network() {
    dialog_answer "$1" yesno yes
    dialog_answer_any -r \
        msgbox "NETWORK CONFIGURATION" "" \
        inputbox "ENTER HOSTNAME" "$NET_HOSTNAME" \
        inputbox "ENTER DOMAINNAME" "$NET_DOMAINNAME" \
        yesno "LOOPBACK ONLY?" no \
        menu "SETUP IP (ADDRESS )?FOR .*" "static IP" \
        inputbox "ENTER (LOCAL IP ADDRESS|IP ADDRESS FOR .*)" "$NET_IPADDR" \
        inputbox "ENTER NETWORK ADDRESS" "$NET_NETWORK" \
        inputbox "ENTER BROADCAST ADDRESS" "$NET_BROADCAST" \
        inputbox "ENTER GATEWAY ADDRESS" "$NET_GATEWAY" \
        inputbox "ENTER NETMASK( .*)?" "$NET_NETMASK" \
        yesno "USE A NAMESERVER[?]" yes \
        inputbox "SELECT NAMESERVER" "$NET_NAMESERVER" \
        menu "PROBE FOR NETWORK CARD[?]" probe \
        msgbox "CARD DETECTED" ok \
        -t msgbox "NETWORK SETUP COMPLETE" ok \
        -t yesno "NETWORK SETUP COMPLETE" yes \
        -t inputmenu "CONFIRM NETWORK SETUP" ""
}

# Install a sendmail.cf suited to a networked host with a nameserver.
dialog_configure_sendmail() {
    dialog_answer "$1" menu "$SENDMAIL_MODE"
	# this has to be handled here to avoid breaking the configuration flow
    dialog_xwmconfig
}

# QEMU's emulated RTC runs on UTC.
dialog_hwclock_utc() {
    dialog_answer "$1" menu YES
}

# Accept the first window manager on the console. 7.0+ runs xwmconfig with the
# installed dialog binary, which bypasses the serial interposer. Its position
# varies so peek briefly at both points and stop checking once answered.
dialog_xwmconfig() {
    if [ "$XWMCONFIG" = true ]; then
        if screen_wait -t 1 "SELECT DEFAULT WINDOW MANAGER FOR X"; then
            kb_press_key spc
            kb_press_key ret
            XWMCONFIG=false
        fi
    fi
}

# Configure the installed system timezone.
dialog_configure_timezone() {
    dialog_answer "$1" menu "$TIMEZONE"
    dialog_xwmconfig
}

# Answer post-install configuration screens until SETUP COMPLETE appears.
dialog_configure() {
    dialog_case \
        yesno "CONFIGURE YOUR SYSTEM?" dialog_yes \
        menu "MAKE BOOTDISK" dialog_skip_boot_disk \
        yesno "MAKE BOOT DISK?" dialog_no \
        msgbox "SKIPPED BOOT DISK CREATION" dialog_ok \
        yesno "MODEM CONFIGURATION" dialog_no \
        menu "MODEM CONFIGURATION" dialog_skip_modem \
        yesno "MOUSE CONFIGURATION" dialog_no \
        menu "MOUSE CONFIGURATION" dialog_configure_mouse \
        yesno "CONFIGURE CD-ROM?" dialog_no \
        yesno "SCREEN FONT CONFIGURATION" dialog_no \
        yesno "CONSOLE FONT CONFIGURATION" dialog_no \
        yesno "FTAPE CONFIGURATION" dialog_no \
        menu "SET YOUR MODEM SPEED" dialog_set_modem_speed \
        menu "INSTALL LINUX KERNEL" dialog_skip_kernel_install \
        menu "INSTALL LILO" dialog_install_lilo \
        menu "LILO INSTALLATION" dialog_install_lilo \
        yesno "CONFIGURE NETWORK?" dialog_configure_network \
        yesno "GPM CONFIGURATION" dialog_no \
        yesno "ENABLE HOTPLUG SUBSYSTEM AT BOOT?" dialog_no \
        yesno "SELECTION 1.5 CONFIGURATION" dialog_no \
        menu "SENDMAIL CONFIGURATION" dialog_configure_sendmail \
        menu "HARDWARE CLOCK SET TO UTC?" dialog_hwclock_utc \
        menu "TIMEZONE CONFIGURATION" dialog_configure_timezone \
        yesno "WARNING: NO ROOT PASSWORD DETECTED" dialog_no \
        -t msgbox "SETUP COMPLETE" dialog_ok
}

# Exit setup after configuration is complete.
dialog_finish() {
    dialog_setup_step EXIT
}

# Reboot from the installed hard disk.
dialog_reboot() {
    script_set_boot c
    kb_press_key ctrl-alt-delete
}

# Run the staged first-boot autoconfiguration script. AUTOCONF_PROMPT
# overrides the first-boot root prompt; 8.1+ uses root@HOSTNAME:~#.
dialog_autoconf() {
    local prompt="${AUTOCONF_PROMPT:-$NET_HOSTNAME:~#}"

    screen_wait -l "$NET_HOSTNAME login:"
    kb_send_line root
    screen_wait -l "$prompt"
    kb_send_line "$FAT_MOUNT/autoinst.d/autoconf.sh"
}

# Set up target partitions and pick the source in this version's order.
dialog_target_source() {
    dialog_format_root
    dialog_mount_fat
    dialog_select_source
}

# Drive the full dialog setup install sequence.
dialog_setup() {
    dialog_login_as_root
    dialog_start_setup
    dialog_select_install_mode
    dialog_enable_swap
    dialog_target_source
    dialog_select_sets
    dialog_configure
    dialog_finish
    dialog_reboot
    dialog_autoconf
}
