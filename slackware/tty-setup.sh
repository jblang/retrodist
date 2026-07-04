# shellcheck shell=bash
#
# Shared QMP driver for Slackware's early tty setup installer.
#
# This script covers the menu-driven installer flow used by Slackware 1.1.1
# through at least 2.2. Version-specific script.sh files should source it,
# override defaults below when needed, then call tty_setup.

SETUP_HOSTNAME=slackware

TARGET_DISK=/dev/hda
SWAP_MB=64

# QEMU exposes the qemu.d/fat directory here; Slackware mounts it at FAT_MOUNT.
FAT_PARTITION=/dev/hdb1
FAT_MOUNT=/retro

# Directory containing packages relative to the qemu.d/fat directory
PACKAGE_DIR=/packages


# These disk sets (and possibly more) are available
#       A   - Base Linux system
#       AP  - Various applications that do not need X
#       D   - Program Development (C, C++, Kernel source, Lisp, Perl, etc.)
#       E   - GNU Emacs
#       F   - FAQ lists
#       IV  - Interviews: libraries, include files, Doc and Idraw apps for X
#       N   - Networking (TCP/IP, UUCP, Mail)
#       TCL - Tcl/Tk/TclX, Tcl language, and Tk toolkit for developing X apps
#       OI  - ObjectBuilder for X
#       OOP - Object Oriented Programming (GNU Smalltalk 1.1.1)
#       X   - XFree-86 2.0 Base X Windows System
#       XAP - X Windows Applications
#       XD  - XFree-86 2.0 X Windows program/server development system
#       XV  - XView 3.2 release 5. (OpenLook [virtual] Window Manager, apps)
#       Y   - Games (that do not require X)
# You may specify any combination of disk sets at the prompt which follows,
# including sets from SLS. For example - to install the base system, base X
# windows, and the Tcl toolkit, you would enter: A X TCL
# Use spaces to seperate the set names. You may use upper or lower case.
PACKAGE_SETS="A AP D E F IV N TCL OI OOP X XAP XD XV Y"

# Network configuration:
NET_HOSTNAME=darkstar
NET_DOMAINNAME=retro.net
NET_IPADDR=10.0.2.15
NET_NETWORK=10.0.2.0
NET_GATEWAY=10.0.2.2
NET_NETMASK=255.255.255.0
NET_BROADCAST=10.0.2.255
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
TIMEZONE=US/Central

# Log in to the installer environment as root.
tty_setup_login_as_root() {
    local LOGIN_PROMPT="$SETUP_HOSTNAME login:"
    script_login
}

# Run the staged partitioning helper for the target disk.
tty_setup_partition_disk() {
    script_shell "mount -t msdos $FAT_PARTITION /mnt"
    script_partition_swaproot "$TARGET_DISK" "$SWAP_MB" /mnt
    script_shell "umount /mnt"
}

# Launch Slackware's tty setup program.
tty_setup_start_setup() {
    script_shell --no-wait "setup"
}

# Keep the default keyboard map.
tty_setup_keep_default_keyboard() {
    script_prompt \
		"Would you like to remap your keyboard?" \
		"1 - yes" \
		"2 - no" \
		"Your choice (1/2)?" "2"
}

# Enable and initialize the configured swap partition.
tty_setup_enable_swap() {
    script_prompt "Do you wish to install this partition as your swapspace ([y]es, [n]o)?" "y"
    script_prompt "Do you want setup to use mkswap on your swap partitions ([y]es, [n]o)?" "y"
}

# Install from scratch and format the root partition as ext2.
tty_setup_format_root_ext2() {
    script_prompt "Would you like to [a]dd more software, or [i]nstall from scratch?" "i"
    script_prompt \
        "What filesystem do you have (or do you plan to use) on your root" \
        "partition (/dev/hda2 ), [e]xt2fs or [x]iafs?" "e"
    script_prompt \
		"Enter [i] again to install from scratch, or [a] to add" \
		"software to your existing system." "i"
    script_prompt "Would you like to format this partition ([y]es, [n]o, [c]heck sectors too)?" "y"
	script_wait_alternative -l \
		"Enter '2048' or '1024', or just hit enter to accept the" \
        "Would you like to set up some of these partitions to be visible"
	if [[ $? == 0 ]]; then
		script_prompt \
		"Enter '2048' or '1024', or just hit enter to accept the" \
		"default of 4096:" "4096"
	fi                                                
}

# Mount the FAT staging partition inside the installed system.
tty_setup_mount_staging_partition() {
    script_prompt \
        "Would you like to set up some of these partitions to be visible" \
        "from Linux ([y]es, [n]o)?" "y"
    script_prompt \
        "Please enter the partition you would like to access from Linux, or" \
        "type <q> to quit adding new partitions:" "$FAT_PARTITION"
    script_prompt "Where would you like to mount $FAT_PARTITION?" "$FAT_MOUNT"
    script_wait_line "Done adding partition $FAT_PARTITION."
	script_prompt \
        "Please enter the partition you would like to access from Linux, or" \
        "type <q> to quit adding new partitions:" "q"
}

# Select the FAT partition as the Slackware package source.
tty_setup_select_hard_drive_source() {
    script_prompt \
		"1 -- Install from a hard drive partition." \
		"From which source will you be installing Linux (1/2/3/4/5)?" "1"
    script_prompt \
        "Please enter the partition where the Slackware sources can be" \
        "found, or [p] to see a partition list:" "$FAT_PARTITION"
    script_prompt "What directory are the Slackware sources in?" "$PACKAGE_DIR"
    script_prompt \
		"1 - FAT (MS-DOS, DR-DOS, OS/2)" \
		"What type of filesystem does your Slackware source partition contain?" "1"
}

# Select the Slackware package sets to install.
tty_setup_select_disk_sets() {
    script_prompt "Which disk sets do you want to install?" "$PACKAGE_SETS"
    script_prompt "Do you want to use PROMPT mode (y/n)?" "y" # note: this doesn't prompt; it uses tagfiles
	script_wait_alternative \
		"Enter your custom tagfile extension (including the leading '.'), or just" \
        "It is recommended that you make a boot disk."
	if [[ $? == 0 ]]; then
		script_prompt \
		"Enter your custom tagfile extension (including the leading '.'), or just" \
		"press ENTER to continue without a custom extension. ==>" ""
	fi
}

# Skip creating an installer boot disk.
tty_setup_skip_boot_disk() {
    script_prompt \
        "It is recommended that you make a boot disk." \
        "Would you like to do this ([y]es, [n]o)?" "n"
}

# Install LILO to the target disk boot sector using 1.x question flow
tty_setup_install_lilo_1x() {
    # LILO, the Linux Loader, allows you to boot Linux directly off your hard drive
    # without using a boot floppy disk.
    # 1. If you are using OS/2's Boot Manager, this choice will allow you to boot
    #    Linux from the Boot Manager menu. If you have already added the Linux
    #    partition to the Boot Manager menu, this choice will complete the Boot
    #    Manager installation process.
    # 2. If you are planning to run Linux as the only operating system on your
    #    machine, use this option to boot directly from the boot sector of your
    #    drive. By the way, LILO may be removed from your boot sector using MS-DOS
    #    fdisk with the command: fdisk /mbr
    # 3. If you're not sure, select 3 to skip LILO and use a boot floppy instead.
    #    You can read more about how to configure LILO manually in /usr/doc/lilo.
    # 4. Install LILO to a formatted floppy. This is a safe choice, and will boot
    #    considerably faster than a normal boot disk.
    script_prompt \
		"LILO (Linux Loader) Installation:" \
		"Which option would you like? (1/2/3/4):" "2"
}

# Install LILO to the target disk boot sector using 2.x+ question flow
tty_setup_install_lilo_2x() {
    script_prompt \
		"LILO INSTALLATION" \
		"1 -- Start LILO configuration with a new LILO header" \
		"Which option would you like (1 - 9)?" "1"
	script_wait_alternative -l \
		"Enter extra parameters==>" \
		"SELECT LILO TARGET LOCATION"
	if [[ $? == 0 ]]; then
		script_press_key ret
	fi                                                
    script_prompt \
		"SELECT LILO TARGET LOCATION" \
		"1. The Master Boot Record of your first hard drive" \
		"Please pick a target location (1 - 3):" "1"
    script_prompt \
		"CHOOSE LILO DELAY" \
		"1 -- None, don't wait at all - boot straight into the first OS" \
		"Which choice would you like (1 - 4)?" "1"
    script_prompt \
		"LILO INSTALLATION" \
		"2 -- Add a Linux partition to the LILO config file" \
		"Which option would you like (1 - 9)?" "2"
    script_prompt \
		"SELECT LINUX PARTITION" \
		"Which one would you like LILO to boot?" "/dev/hda2"
    script_prompt \
		"SELECT PARTITION NAME" \
		"Enter name:" "linux"
    script_prompt \
		"LILO INSTALLATION" \
		"5 -- Install LILO" \
		"Which option would you like (1 - 9)?" "5"
}

# Skip CD-ROM configuration.
setup_dispatch_questions() {
	while true; do
		script_wait_alternative -l \
			"LILO (Linux Loader) Installation:" \
			"LILO INSTALLATION" \
			"Enter speed ==>" \
			"Would you like to set up your modem ([y]es, [n]o)?" \
			"Would you like to set up your mouse ([y]es, [n]o)?" \
			"Do you have a CD-ROM ([y]es, [n]o)?" \
			"Would you like to try out some custom screen fonts ([y]es, [n]o)?" \
			"Would you like to load the FTAPE module at boot time ([y]es, [n]o)?"
		case $? in
		0) # 1.x lilo configuration
			tty_setup_install_lilo_1x
			break
			;;
		1) # 2.0+ lilo configuration
			tty_setup_install_lilo_2x
			break
			;;
		2) # modem speed
			script_prompt \
				"SELECT DEFAULT MODEM SPEED" \
				"Enter speed ==>" "38400"
			;;
		*) # optional steps (answer no)
			script_send_line "n"
			;;
		esac
	done
}

# Configure TCP/IP networking with the selected NET_* values.
tty_setup_configure_network() {
    script_prompt "Would you like to configure your network ([y]es, [n]o)?" "y"
    script_prompt "Enter hostname:" "$NET_HOSTNAME"
    script_prompt "Enter domain name for $NET_HOSTNAME:" "$NET_DOMAINNAME"
    script_prompt "Do you plan to ONLY use loopback ([y]es, [n]o)?" "n"
    script_prompt "Enter IP address for $NET_HOSTNAME (aaa.bbb.ccc.ddd):" "$NET_IPADDR"
    script_prompt "Enter network address (aaa.bbb.ccc.ddd):" "$NET_NETWORK"
    script_prompt "Enter gateway address (aaa.bbb.ccc.ddd):" "$NET_GATEWAY"
    script_prompt "Enter netmask (aaa.bbb.ccc.ddd):" "$NET_NETMASK"
    script_prompt "Enter broadcast address (aaa.bbb.ccc.ddd):" "$NET_BROADCAST"
    script_prompt "Name Server for domain $NET_DOMAINNAME (aaa.bbb.ccc.ddd):" "$NET_NAMESERVER"
}

# Skip loading the selection daemon from rc.local.
tty_setup_skip_selection_daemon() {
    script_prompt \
        'Would you like to add "selection -t none &" to /etc/rc.d/rc.local so that' \
        "selection will load at boot time ([y]es, [n]o)?" "n"
}

# Configure the installed system timezone.
tty_setup_configure_timezone() {
    script_prompt "Would you like to configure your timezone ([y]es, [n]o)?" "y"
    script_prompt "Select one of these timezones:" "Timezone?" "$TIMEZONE"
}

# Reboot from the installed hard disk.
tty_setup_reboot_to_installed_system() {
    script_wait_line "You may now reboot your computer by pressing control+alt+delete."
    script_set_boot c
    script_press_key ctrl-alt-delete
}

# Run the staged first-boot autoconfiguration script.
tty_setup_run_first_boot_autoconf() {
    local SHELL_PROMPT="$NET_HOSTNAME:~#"
    local LOGIN_PROMPT="$NET_HOSTNAME login:"

    script_login
    script_shell --no-wait "$FAT_MOUNT/autoinst.d/autoconf.sh"
}

# Drive the full tty setup install sequence.
tty_setup() {
    tty_setup_login_as_root
    tty_setup_partition_disk
    tty_setup_start_setup
    tty_setup_keep_default_keyboard
    tty_setup_enable_swap
    tty_setup_format_root_ext2
    tty_setup_mount_staging_partition
    tty_setup_select_hard_drive_source
    tty_setup_select_disk_sets
    tty_setup_skip_boot_disk
	setup_dispatch_questions
    tty_setup_configure_network
    tty_setup_skip_selection_daemon
    tty_setup_configure_timezone
    tty_setup_reboot_to_installed_system
    tty_setup_run_first_boot_autoconf
}
