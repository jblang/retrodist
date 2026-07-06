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

script_prompt "darkstar login:" "root"

script_shell "mount -t msdos /dev/hdb1 /mnt"
script_partition_swaproot "/dev/hda" "64"
script_shell "umount /mnt"

script_shell --no-wait "setup"

script_prompt \
	"Would you like to remap your keyboard?" \
	"1 - yes" \
	"2 - no" \
	"Your choice (1/2)?" "2"

script_prompt "Do you wish to install this partition as your swapspace ([y]es, [n]o)?" "y"
script_prompt "Do you want setup to use mkswap on your swap partitions ([y]es, [n]o)?" "y"

script_prompt "Would you like to [a]dd more software, or [i]nstall from scratch?" "i"

script_prompt \
    "What filesystem do you have (or do you plan to use) on your root" \
    "partition (/dev/hda2 ), [e]xt2fs or [x]iafs?" "e"

script_prompt "Enter [i] again to install from scratch, or [a] to add" "i"
script_prompt "Would you like to format this partition ([y]es, [n]o, [c]heck sectors too)?" "y"

script_prompt \
    "Would you like to set up some of these partitions to be visible" \
    "from Linux ([y]es, [n]o)?" "y"

script_prompt \
    "Please enter the partition you would like to access from Linux, or" \
    "type <q> to quit adding new partitions:" "/dev/hdb1"

script_prompt "Where would you like to mount /dev/hdb1?" "/retro"
script_prompt "Done adding partition /dev/hdb1." "q"

script_prompt "1 -- Install from a hard drive partition." "1"
script_prompt \
    "Please enter the partition where the Slackware sources can be" \
    "found, or [p] to see a partition list:" "/dev/hdb1"

script_prompt "What directory are the Slackware sources in?" "/packages"
script_prompt "What type of filesystem does your Slackware source partition contain?" "1" # FAT
script_prompt "Which disk sets do you want to install?" "$PACKAGE_SETS"
 # note: this doesn't actually prompt; it uses tagfiles
script_prompt "Do you want to use PROMPT mode (y/n)?" "y"

script_prompt \
	"It is recommended that you make a boot disk." \
	"Would you like to do this ([y]es, [n]o)?" "n"

script_prompt "Would you like to set up your modem ([y]es, [n]o)?" "n"

script_prompt "Would you like to set up your mouse ([y]es, [n]o)?" "n"

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

script_prompt "Would you like to configure your network ([y]es, [n]o)?" "y"
script_prompt "Enter hostname:" "$NET_HOSTNAME"
script_prompt "Enter domain name for darkstar:" "$NET_DOMAINNAME"
script_prompt "Do you plan to ONLY use loopback ([y]es, [n]o)?" "n"
script_prompt "Enter IP address for darkstar (aaa.bbb.ccc.ddd):" "$NET_IPADDR"
script_prompt "Enter network address (aaa.bbb.ccc.ddd):" "$NET_NETWORK"
script_prompt "Enter gateway address (aaa.bbb.ccc.ddd):" "$NET_GATEWAY"
script_prompt "Enter netmask (aaa.bbb.ccc.ddd):" "$NET_NETMASK"
script_prompt "Enter broadcast address (aaa.bbb.ccc.ddd):" "$NET_BROADCAST"
script_prompt "Name Server for domain retro.net (aaa.bbb.ccc.ddd):" "$NET_NAMESERVER"

script_prompt \
    'Would you like to add "selection -t none &" to /etc/rc.d/rc.local so that' \
    "selection will load at boot time ([y]es, [n]o)?" "n"

script_prompt "Would you like to configure your timezone ([y]es, [n]o)?" "y"
script_prompt \
	"Select one of these timezones:" \
	"Timezone?" "$TIMEZONE"

script_wait_line "You may now reboot your computer by pressing control+alt+delete."
script_set_boot c
script_press_key ctrl-alt-delete

script_prompt "$NET_HOSTNAME login:" root
script_prompt "$NET_HOSTNAME:~#" /retro/autoinst.d/autoconf.sh
