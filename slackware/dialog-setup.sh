# shellcheck shell=bash
# Shared driver for Slackware 1.1.2-2.3 dialog-based setup.

SETUP_HOSTNAME=slackware

TARGET_DISK=/dev/hda
SWAP_MB=64

# QEMU exposes qemu.d/fat here; Slackware mounts it at FAT_MOUNT.
FAT_PARTITION=/dev/hdb1
FAT_MOUNT=/retro

SETUP_SOURCE=/dev/hdc

LINUX_PARTITION=/dev/hda2
LINUX_PARTITION_NAME=linux

# Custom tagfiles let PROMPT mode work from read-only media.
PROMPT_MODE=Path
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
    serial_shell_send "mv /bin/dialog /bin/dialog.bak" || return 1
    serial_shell_send "cp $FAT_MOUNT/autoinst.d/dialog.sh /bin/dialog" || return 1
    serial_shell_send --no-wait "fdisk $TARGET_DISK" || return 1
    script_fdisk_partitions "$SWAP_MB" || return 1
    serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1
    serial_shell_exit || return 1
    kb_send_line "setup" || return 1
    dialog_setup_step ADDSWAP
}

# Choose a step from the Slackware Linux Setup main menu.
dialog_setup_step() {
    dialog_answer -r "Slackware Linux Setup \(version .*\)" menu "$1"
}

# Install the detected swap partition and let setup activate it.
dialog_enable_swap() {
    dialog_yes "SWAP SPACE DETECTED"
    dialog_ok "MKSWAP WARNING"
    dialog_yes "USE MKSWAP?"
    dialog_yes "ACTIVATE SWAP SPACE?"
    dialog_ok "SWAP SPACE CONFIGURED"
    dialog_yes "CONTINUE WITH INSTALLATION?"
}

# Format root, answering only the optional screens this setup version raises.
dialog_format_root() {
    dialog_ok "Using this partition for Linux:"
    dialog_answer_any \
        "CHOOSE LINUX FILESYSTEM" ext2 \
        "FORMAT PARTITION" Format \
        "SELECT INODE DENSITY" 4096 \
        "DOS AND OS/2 PARTITION SETUP"
}

# Mount the FAT staging partition so it's visible from the installed system.
dialog_mount_fat() {
    dialog_yes "DOS AND OS/2 PARTITION SETUP"
    dialog_answer "CHOOSE PARTITION" inputbox "$FAT_PARTITION"
    dialog_answer "SELECT MOUNT POINT" inputbox "$FAT_MOUNT"
    dialog_ok "CURRENT DOS/HPFS PARTITION STATUS"
    dialog_answer "CHOOSE PARTITION" inputbox q
    dialog_yes "CONTINUE?"
}

# Select the IDE CD-ROM drive as the Slackware package source.
dialog_select_source() {
	if [[ $SETUP_SOURCE == "/dev/hdc" ]]; then
		dialog_answer "SOURCE MEDIA SELECTION" menu 5 # CD-ROM
		dialog_answer "Install from the Slackware CD-ROM" menu 7 # IDE
		dialog_answer "SELECT IDE DEVICE" menu "$SETUP_SOURCE"
		dialog_answer "Pick your installation method" menu slakware
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
    dialog_answer "SERIES SELECTION" checklist "$PACKAGE_SETS"
    dialog_yes "CONTINUE?"
    dialog_answer "SELECT PROMPTING MODE" menu "$PROMPT_MODE"
    if [ "$PROMPT_MODE" = Path ]; then
        dialog_answer "PROVIDE A CUSTOM PATH TO YOUR TAGFILES" inputbox "$TAGFILE_PATH"
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

# Install LILO to the target disk MBR, handling the optional append= screen.
dialog_install_lilo() {
    dialog_answer "$1" menu Begin
    dialog_answer_any \
        "OPTIONAL append= LINE" "" \
        "SELECT LILO TARGET LOCATION"
    dialog_answer "SELECT LILO TARGET LOCATION" menu MBR
    dialog_answer "CHOOSE LILO DELAY" "" None
    dialog_answer "LILO INSTALLATION" menu Linux
    dialog_answer "SELECT LINUX PARTITION" "" "$LINUX_PARTITION"
    dialog_answer "SELECT PARTITION NAME" "" "$LINUX_PARTITION_NAME"
    dialog_answer "LILO INSTALLATION" menu Install
}

# Configure TCP/IP with NET_* values; prompt order varies by version.
dialog_configure_network() {
    dialog_answer "$1" "" yes
    dialog_answer_any \
        "NETWORK CONFIGURATION" "" \
        "ENTER HOSTNAME" "$NET_HOSTNAME" \
        "ENTER DOMAINNAME" "$NET_DOMAINNAME" \
        "LOOPBACK ONLY?" no \
        "ENTER LOCAL IP ADDRESS" "$NET_IPADDR" \
        "ENTER NETWORK ADDRESS" "$NET_NETWORK" \
        "ENTER BROADCAST ADDRESS" "$NET_BROADCAST" \
        "ENTER GATEWAY ADDRESS" "$NET_GATEWAY" \
        "ENTER NETMASK" "$NET_NETMASK" \
        "USE A NAMESERVER?" yes \
        "SELECT NAMESERVER" "$NET_NAMESERVER" \
        "NETWORK SETUP COMPLETE"
    dialog_ok "NETWORK SETUP COMPLETE"
}

# Install a sendmail.cf suited to a networked host with a nameserver.
dialog_configure_sendmail() {
    dialog_answer "$1" "" "$SENDMAIL_MODE"
}

# Configure the installed system timezone.
dialog_configure_timezone() {
    dialog_answer "$1" "" "$TIMEZONE"
}

# Answer post-install configuration screens until SETUP COMPLETE appears.
dialog_configure() {
    dialog_case \
        "CONFIGURE YOUR SYSTEM?" dialog_yes \
        "MAKE BOOTDISK" dialog_skip_boot_disk \
        "MAKE BOOT DISK?" dialog_no \
        "SKIPPED BOOT DISK CREATION" dialog_ok \
        "MODEM CONFIGURATION" dialog_no \
        "MOUSE CONFIGURATION" dialog_no \
        "CONFIGURE CD-ROM?" dialog_no \
        "SCREEN FONT CONFIGURATION" dialog_no \
        "FTAPE CONFIGURATION" dialog_no \
        "SET YOUR MODEM SPEED" dialog_set_modem_speed \
        "LILO INSTALLATION" dialog_install_lilo \
        "CONFIGURE NETWORK?" dialog_configure_network \
        "GPM CONFIGURATION" dialog_no \
        "SELECTION 1.5 CONFIGURATION" dialog_no \
        "SENDMAIL CONFIGURATION" dialog_configure_sendmail \
        "TIMEZONE CONFIGURATION" dialog_configure_timezone \
        "SETUP COMPLETE"
}

# Acknowledge that configuration is complete and exit setup.
dialog_finish() {
    dialog_ok "SETUP COMPLETE"
    dialog_setup_step EXIT
}

# Reboot from the installed hard disk.
dialog_reboot() {
    script_set_boot c
    kb_press_key ctrl-alt-delete
}

# Run the staged first-boot autoconfiguration script.
dialog_autoconf() {
    local SHELL_PROMPT="$NET_HOSTNAME:~#"

    screen_wait -l "$NET_HOSTNAME login:"
    kb_send_line root
    screen_wait -l "$SHELL_PROMPT"
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
    dialog_enable_swap
    dialog_target_source
    dialog_select_sets
    dialog_configure
    dialog_finish
    dialog_reboot
    dialog_autoconf
}
