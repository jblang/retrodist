# shellcheck shell=bash
#
# Shared QMP driver for Slackware's dialog-based setup installer.
#
# This script covers Slackware 1.1.2-2.3, whose boot/root disks include a
# real `dialog` binary. autoinst/dialog.sh is copied over /bin/dialog before
# `setup` runs, turning every dialog widget into a plain-text prompt with a
# "TITLE:" header and a trailing "RESPONSE:" line. That fixed shape is what
# dialog_answer matches against. Version-specific script.sh files should
# source it, override defaults below when needed, then call dialog_setup.

SETUP_HOSTNAME=slackware

TARGET_DISK=/dev/hda
SWAP_MB=64

# QEMU exposes the qemu.d/fat directory here; Slackware mounts it at FAT_MOUNT.
FAT_PARTITION=/dev/hdb1
FAT_MOUNT=/retro

SETUP_SOURCE=/dev/hdc

LINUX_PARTITION=/dev/hda2
LINUX_PARTITION_NAME=linux

# Custom tagfiles let PROMPT mode work when installing from read-only media.
# 1.1.2 has no Path mode; override to Normal to use the tagfiles staged in
# the package directories.
PROMPT_MODE=Path
TAGFILE_PATH=/retro/tagfiles

MODEM_SPEED=38400
SENDMAIL_MODE=SMTP

# These disk sets (and possibly more) are available
#       A   - Base Linux system
#       AP  - Various applications that do not need X
#       D   - Program Development (C, C++, Kernel source, Lisp, Perl, etc.)
#       E   - GNU Emacs
#       F   - FAQ lists, HOWTO documentation
#       I   - Info files readable with info, JED, or Emacs
#       IV  - Interviews: libraries, include files, Doc and Idraw apps for X
#       N   - Networking (TCP/IP, UUCP, Mail, News)
#       OOP - Object Oriented Programming (GNU Smalltalk)
#       Q   - Extra Linux kernels with UMSDOS/non-SCSI CD drivers
#       T   - TeX
#       TCL - Tcl/Tk/TclX, Tcl language, and Tk toolkit for X
#       X   - XFree86 X Window System
#       XAP - X Applications
#       XD  - XFree86 X11 Server Development System
#       XV  - XView (OpenLook Window Manager, apps)
#       Y   - Games (that do not require X)
# The SERIES SELECTION screen is a checklist, so each set must be its own
# quoted token rather than a bare space-separated word.
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

# Select one of these timezones:
# Australia/LHI Australia/NSW Australia/North Australia/Queensland
# Australia/South Australia/Tasmania Australia/Victoria Australia/West
# Australia/Yancowinna Brazil/Acre Brazil/DeNoronha Brazil/East Brazil/West
# Canada/Atlantic Canada/Central Canada/East-Saskatche Canada/Eastern
# Canada/Mountain Canada/Newfoundland Canada/Pacific Canada/Yukon
# Chile/Continental Chile/EasterIsland CET Cuba EET Egypt Factory GB-Eire GMT
# GMT+0 GMT+1 GMT+10 GMT+11 GMT+12 GMT+13 GMT+2 GMT+3 GMT+4 GMT+5 GMT+6 GMT+7
# GMT+8 GMT+9 GMT-0 GMT-1 GMT-10 GMT-11 GMT-12 GMT-2 GMT-3 GMT-4 GMT-5 GMT-6 GMT-
# GMT-8 GMT-9 GMT0 GMT1 GMT10 GMT11 GMT12 GMT13 GMT2 GMT3 GMT4 GMT5 GMT6 GMT7
# GMT8 GMT9 Greenwich Hongkong Iceland Iran Israel Jamaica Japan Libya
# Mexico/BajaNorte Mexico/BajaSur Mexico/General MET NZ Navajo PRC Poland ROC ROK
# Singapore SystemV/AST4 SystemV/AST4ADT SystemV/CST6 SystemV/CST6CDT
# SystemV/EST5 SystemV/EST5EDT SystemV/MST7 SystemV/MST7MDT
# SystemV/PST8 SystemV/PST8PDT SystemV/YST9 SystemV/YST9YDT Turkey UCT UTC
# Universal US/Alaska US/Aleutian US/Arizona US/Central US/East-Indiana
# US/Eastern US/Hawaii US/Michigan US/Mountain US/Pacific US/Pacific-New US/Samoa
# W-SU WET Zulu
TIMEZONE=UTC

# Waits for one dialog screen by its title — and its widget type, when given
# — then sends the answer that follows its "RESPONSE:" prompt. Covers menu,
# yesno, inputbox, checklist, and msgbox widgets alike, since the adapter
# prompts for a response (even if blank) on all of them except infobox.
# Usage: dialog_answer [-r] TITLE [TYPE] ANSWER
# Pass -r to match the title as an extended regex pattern instead of literal text.
dialog_answer() {
    local args=()
    if [ "${1:-}" = "-r" ]; then
        args+=(-r)
        shift
    fi
    args+=("TITLE: $1")
    if [ $# -eq 3 ]; then
        args+=("TYPE: $2" "RESPONSE:" "$3")
    else
        args+=("RESPONSE:" "$2")
    fi
    script_prompt "${args[@]}"
}

# Handles dialog screens in whatever order the installer raises them. Each
# TITLE HANDLER pair names a screen and a function or command to run when
# that screen appears. The last argument is a terminating title: dialog_case
# returns as soon as it appears, leaving that screen unanswered.
# The handler receives the matched title as its only argument and should
# answer the screen itself, e.g. with dialog_answer. Each pair is handled
# once; list a title more than once to handle each occurrence in the order
# given.
# Pass -r to match titles as extended regex patterns instead of literal text.
dialog_case() {
    local wait_opt=-l
    local usage="dialog_case requires [-r] [TITLE HANDLER ...] TERMINATOR"
    local terminator titles=() handlers=() answered=()
    local pending=() map=() count matched i

    if [ "${1:-}" = "-r" ]; then
        wait_opt=-r
        shift
    fi

    [ $(($# % 2)) -eq 1 ] || die "$usage"
    terminator=${!#}

    while [ $# -gt 1 ]; do
        titles+=("$1")
        handlers+=("$2")
        answered+=(false)
        shift 2
    done

    count=${#titles[@]}
    while :; do
        pending=("TITLE: $terminator")
        map=(0)
        for ((i = 0; i < count; i++)); do
            if [ "${answered[$i]}" = false ]; then
                pending+=("TITLE: ${titles[$i]}")
                map+=("$i")
            fi
        done
        script_wait_alternative "$wait_opt" "${pending[@]}"
        matched=$?
        if [ "$matched" -eq 0 ]; then
            return 0
        fi
        i=${map[$matched]}
        "${handlers[$i]}" "${titles[$i]}"
        answered[i]=true
    done
}

# Like dialog_case, but takes TITLE ANSWER pairs: each matched screen is
# answered with dialog_answer directly instead of through a handler.
# Pass -r to match titles as extended regex patterns instead of literal text.
dialog_answer_any() {
    local wait_opt=-l
    local usage="dialog_answer_any requires [-r] [TITLE ANSWER ...] TERMINATOR"
    local terminator titles=() answers=() answered=()
    local pending=() map=() count matched i

    if [ "${1:-}" = "-r" ]; then
        wait_opt=-r
        shift
    fi

    [ $(($# % 2)) -eq 1 ] || die "$usage"
    terminator=${!#}

    while [ $# -gt 1 ]; do
        titles+=("$1")
        answers+=("$2")
        answered+=(false)
        shift 2
    done

    count=${#titles[@]}
    while :; do
        pending=("TITLE: $terminator")
        map=(0)
        for ((i = 0; i < count; i++)); do
            if [ "${answered[$i]}" = false ]; then
                pending+=("TITLE: ${titles[$i]}")
                map+=("$i")
            fi
        done
        script_wait_alternative "$wait_opt" "${pending[@]}"
        matched=$?
        if [ "$matched" -eq 0 ]; then
            return 0
        fi
        i=${map[$matched]}
        if [ "$wait_opt" = -r ]; then
            dialog_answer -r "${titles[$i]}" "${answers[$i]}"
        else
            dialog_answer "${titles[$i]}" "${answers[$i]}"
        fi
        answered[i]=true
    done
}

# Log in to the installer environment as root.
dialog_login_as_root() {
    local LOGIN_PROMPT="$SETUP_HOSTNAME login:"
    script_login
}

# Perform pre-setup steps and then start the setup script
dialog_start_setup() {
    script_shell \
		"mkdir -p $FAT_MOUNT" \
        "mount -t msdos $FAT_PARTITION $FAT_MOUNT" \
        "mv /bin/dialog /bin/dialog.bak" \
        "cp $FAT_MOUNT/autoinst.d/dialog.sh /bin/dialog"
    script_partition_swaproot "$TARGET_DISK" "$SWAP_MB" "$FAT_MOUNT"
    script_shell --no-wait "setup"
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

# Format the root partition, answering only the screens this version's setup
# raises: the filesystem choice through 2.1, inode density from 2.1 on. The
# DOS partition screen that follows ends the sequence and is answered by
# dialog_mount_fat.
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

# The functions below are dialog_case handlers for the post-install
# configuration screens: each receives the matched title and answers that
# screen (and any screens that follow from it).

# Accept an optional configuration screen.
dialog_yes() {
    dialog_answer "$1" yesno yes
}

# Decline an optional configuration screen (modem, mouse, CD-ROM, screen
# font, FTAPE, gpm).
dialog_no() {
    dialog_answer "$1" yesno no
}

# Acknowledge an informational screen.
dialog_ok() {
    dialog_answer "$1" msgbox ok
}

# Skip creating an installer boot disk.
dialog_skip_boot_disk() {
    dialog_answer "$1" menu continue
}

# Answer the modem speed selection with MODEM_SPEED.
dialog_set_modem_speed() {
    dialog_answer "$1" menu "$MODEM_SPEED"
}

# Install LILO to the target disk's master boot record. The append= screen
# is only asked from 2.1 on, so answer it if it appears before the target
# location menu.
dialog_install_lilo() {
    dialog_answer "$1" menu Begin
    dialog_answer_any \
        "OPTIONAL append= LINE" "" \
        "SELECT LILO TARGET LOCATION"
    dialog_answer "SELECT LILO TARGET LOCATION" menu MBR
    dialog_answer "CHOOSE LILO DELAY" None
    dialog_answer "LILO INSTALLATION" menu Linux
    dialog_answer "SELECT LINUX PARTITION" "$LINUX_PARTITION"
    dialog_answer "SELECT PARTITION NAME" "$LINUX_PARTITION_NAME"
    dialog_answer "LILO INSTALLATION" menu Install
}

# Configure TCP/IP networking with the selected NET_* values. The prompt
# order varies across versions (2.0 and earlier ask for the network address
# before the gateway), so answer them in whatever order they appear.
dialog_configure_network() {
    dialog_answer "$1" yes
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
    dialog_answer "$1" "$SENDMAIL_MODE"
}

# Configure the installed system timezone.
dialog_configure_timezone() {
    dialog_answer "$1" "$TIMEZONE"
}

# Answer the post-install configuration screens in whatever order this
# Slackware version asks them, returning when SETUP COMPLETE appears.
# Screens a version never shows (including the boot disk title's other
# spelling) are simply abandoned at that point.
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
    script_press_key ctrl-alt-delete
}

# Run the staged first-boot autoconfiguration script.
dialog_autoconf() {
    # shellcheck disable=SC2034 # Used by script_login via dynamic scope.
    local LOGIN_PROMPT="$NET_HOSTNAME login:"
    # shellcheck disable=SC2034 # Used by script_shell via dynamic scope.
    local SHELL_PROMPT="$NET_HOSTNAME:~#"

    script_login
    script_shell --no-wait "$FAT_MOUNT/autoinst.d/autoconf.sh"
}

# Set up the target partitions and pick the source in this version's chained
# order; 1.1.2 asks SOURCE before TARGET, so its script overrides this.
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
