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
# Brazil/West             GMT-6                   SystemV/EST5
# Canada/Atlantic         GMT-                    SystemV/EST5EDT
# Canada/Central          GMT-8                   SystemV/MST7
# Canada/East-Saskatche   GMT-9                   SystemV/MST7MDT
# Canada/Eastern          GMT0                    SystemV/PST8
# Canada/Mountain         GMT1                    SystemV/PST8PDT
# Canada/Newfoundland     GMT10                   SystemV/YST9
# Canada/Pacific          GMT11                   SystemV/YST9YDT
# Canada/Yukon            GMT12                   Turkey
# Chile/Continental       GMT13                   UCT
# Chile/EasterIsland      GMT2                    UTC
# CET                     GMT3                    Universal
# Cuba                    GMT4                    US/Alaska
# EET                     GMT5                    US/Aleutian
# Egypt                   GMT6                    US/Arizona
# Factory                 GMT7                    US/Central
# GB-Eire                 GMT8                    US/East-Indiana
# GMT                     GMT9                    US/Eastern
# GMT+0                   Greenwich               US/Hawaii
# GMT+1                   Hongkong                US/Michigan
# GMT+10                  Iceland                 US/Mountain
# GMT+11                  Iran                    US/Pacific
# GMT+12                  Israel                  US/Pacific-New
# GMT+13                  Jamaica                 US/Samoa
# GMT+2                   Japan                   W-SU
# GMT+3                   Libya                   WET
# GMT+4                   Mexico/BajaNorte        Zulu
# GMT+5                   Mexico/BajaSur
# GMT+6                   Mexico/General
TIMEZONE=US/Central

vga_wait -l "darkstar login:"
kb_type -n "root"

serial_shell_start || return 1
fdisk_start /dev/hda || return 1
fdisk_partitions 64 || return 1
serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1
serial_console_divider || return 1
serial_console_echo \
    "Starting Slackware setup; package installation may take a while..." || return 1
serial_shell_send --no-wait "setup" || return 1

serial_prompt \
	"Would you like to remap your keyboard?" \
	"1 - yes" \
	"2 - no" \
	"Your choice (1/2)?" "2"

serial_prompt "Do you wish to install this partition as your swapspace ([y]es, [n]o)?" "y"
serial_prompt "Do you want setup to use mkswap on your swap partitions ([y]es, [n]o)?" "y"

serial_prompt "Would you like to [a]dd more software, or [i]nstall from scratch?" "i"

serial_prompt \
    "What filesystem do you have (or do you plan to use) on your root" \
    "partition (/dev/hda2 ), [e]xt2fs or [x]iafs?" "e"

serial_prompt "Enter [i] again to install from scratch, or [a] to add" "i"
serial_prompt "Would you like to format this partition ([y]es, [n]o, [c]heck sectors too)?" "y"

serial_prompt \
    "Would you like to set up some of these partitions to be visible" \
    "from Linux ([y]es, [n]o)?" "y"

serial_prompt \
    "Please enter the partition you would like to access from Linux, or" \
    "type <q> to quit adding new partitions:" "/dev/hdb1"

serial_prompt "Where would you like to mount /dev/hdb1?" "/retro"
serial_prompt "Done adding partition /dev/hdb1." "q"

serial_prompt "1 -- Install from a hard drive partition." "1"
serial_prompt \
    "Please enter the partition where the Slackware sources can be" \
    "found, or [p] to see a partition list:" "/dev/hdb1"

serial_prompt "What directory are the Slackware sources in?" "/packages"
serial_prompt "What type of filesystem does your Slackware source partition contain?" "1" # FAT
serial_prompt "Which disk sets do you want to install?" "$PACKAGE_SETS"
 # note: this doesn't actually prompt; it uses tagfiles
serial_prompt "Do you want to use PROMPT mode (y/n)?" "y"

serial_prompt \
	"It is recommended that you make a boot disk." \
	"Would you like to do this ([y]es, [n]o)?" "n"

serial_prompt "Would you like to set up your modem ([y]es, [n]o)?" "n"

serial_prompt "Would you like to set up your mouse ([y]es, [n]o)?" "n"

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
serial_prompt \
	"LILO (Linux Loader) Installation:" \
	"Which option would you like? (1/2/3/4):" "2"

serial_prompt "Would you like to configure your network ([y]es, [n]o)?" "y"
serial_prompt "Enter hostname:" "$NET_HOSTNAME"
serial_prompt "Enter domain name for darkstar:" "$NET_DOMAINNAME"
serial_prompt "Do you plan to ONLY use loopback ([y]es, [n]o)?" "n"
serial_prompt "Enter IP address for darkstar (aaa.bbb.ccc.ddd):" "$NET_IPADDR"
serial_prompt "Enter network address (aaa.bbb.ccc.ddd):" "$NET_NETWORK"
serial_prompt "Enter gateway address (aaa.bbb.ccc.ddd):" "$NET_GATEWAY"
serial_prompt "Enter netmask (aaa.bbb.ccc.ddd):" "$NET_NETMASK"
serial_prompt "Enter broadcast address (aaa.bbb.ccc.ddd):" "$NET_BROADCAST"
serial_prompt "Name Server for domain retro.net (aaa.bbb.ccc.ddd):" "$NET_NAMESERVER"

serial_prompt \
    'Would you like to add "selection -t none &" to /etc/rc.d/rc.local so that' \
    "selection will load at boot time ([y]es, [n]o)?" "n"

serial_prompt "Would you like to configure your timezone ([y]es, [n]o)?" "y"
serial_prompt \
	"Select one of these timezones:" \
	"Timezone?" "$TIMEZONE"

serial_wait -l "You may now reboot your computer by pressing control+alt+delete."
script_set_boot c
kb_press ctrl-alt-delete

vga_wait -l "$NET_HOSTNAME login:"
kb_type -n "root"
vga_wait -l "$NET_HOSTNAME:~#"
kb_type -n /retro/guestlib.d/postinst.sh
