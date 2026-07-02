script_wait_line "darkstar login:"
script_send_line root

script_wait_line "#"
script_send_line "mount -t msdos /dev/hdb1 /mnt &&
/mnt/autoinst.d/diskpart.sh /dev/hda 64 &&
umount /mnt"

script_wait_line "#"
script_send_line "setup"

script_wait_line "Would you like to remap your keyboard?"
script_send_line "2" # no

script_wait_line "Do you wish to install this partition as your swapspace ([y]es, [n]o)?"
script_send_line "y"
script_wait_line "Do you want setup to use mkswap on your swap partitions ([y]es, [n]o)?"
script_send_line "y"

script_wait_line "Would you like to [a]dd more software, or [i]nstall from scratch?"
script_send_line "i"
script_wait_line "What filesystem do you have (or do you plan to use) on your root"
script_wait_line "partition (/dev/hda2 ), [e]xt2fs or [x]iafs?"
script_send_line "e"
script_wait_line "Enter [i] again to install from scratch, or [a] to add"
script_send_line "i"
script_wait_line "Would you like to format this partition ([y]es, [n]o, [c]heck sectors too)?"
script_send_line "y"

script_wait_line "Would you like to set up some of these partitions to be visible"
script_wait_line "from Linux ([y]es, [n]o)?"
script_send_line "y"
script_wait_line "Please enter the partition you would like to access from Linux, or"
script_wait_line "type <q> to quit adding new partitions:"
script_send_line "/dev/hdb1"
script_wait_line "Where would you like to mount /dev/hdb1?"
script_send_line "/retro"
script_wait_line "Done adding partition /dev/hdb1."
script_send_line "q"

script_wait_line "1 -- Install from a hard drive partition."
script_send_line "1"
script_wait_line "Please enter the partition where the Slackware sources can be"
script_wait_line "found, or [p] to see a partition list:"
script_send_line "/dev/hdb1"
script_wait_line "What directory are the Slackware sources in?"
script_send_line "/packages"
script_wait_line "What type of filesystem does your Slackware source partition contain?"
script_send_line "1" # FAT

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
script_wait_line "Which disk sets do you want to install?"
script_send_line "A AP D E F IV N TCL OI OOP X XAP XD XV Y"
script_wait_line "Do you want to use PROMPT mode (y/n)?"
script_send_line "y" # note: this doesn't prompt; it uses tagfiles

script_wait_line "It is recommended that you make a boot disk." 600
script_wait_line "Would you like to do this ([y]es, [n]o)?"
script_send_line "n"

script_wait_line "Would you like to set up your modem ([y]es, [n]o)?"
script_send_line "n"

script_wait_line "Would you like to set up your mouse ([y]es, [n]o)?"
script_send_line "n"

script_wait_line "LILO (Linux Loader) Installation:"
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
script_wait_line "Which option would you like? (1/2/3/4):"
script_send_line "2"

script_wait_line "Would you like to configure your network ([y]es, [n]o)?"
script_send_line "y"
script_wait_line "Enter hostname:"
script_send_line "darkstar"
script_wait_line "Enter domain name for darkstar:"
script_send_line "retro.net"
script_wait_line "Do you plan to ONLY use loopback ([y]es, [n]o)?"
script_send_line "n"
script_wait_line "Enter IP address for darkstar (aaa.bbb.ccc.ddd):"
script_send_line "10.0.2.15"
script_wait_line "Enter network address (aaa.bbb.ccc.ddd):"
script_send_line "10.0.2.0"
script_wait_line "Enter gateway address (aaa.bbb.ccc.ddd):"
script_send_line "10.0.2.2"
script_wait_line "Enter netmask (aaa.bbb.ccc.ddd):"
script_send_line "255.255.255.0"
script_wait_line "Enter broadcast address (aaa.bbb.ccc.ddd):"
script_send_line "10.0.2.255"
script_wait_line "Name Server for domain retro.net (aaa.bbb.ccc.ddd):"
script_send_line "10.0.2.3"

script_wait_line 'Would you like to add "selection -t none &" to /etc/rc.d/rc.local so that'
script_wait_line "selection will load at boot time ([y]es, [n]o)?"
script_send_line "n"

script_wait_line "Would you like to configure your timezone ([y]es, [n]o)?"
script_send_line "y"
script_wait_line "Select one of these timezones:"
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
# SystemV/EST5 SystemV/EST5EDT SystemV/HST10 SystemV/MST7 SystemV/MST7MDT
# SystemV/PST8 SystemV/PST8PDT SystemV/YST9 SystemV/YST9YDT Turkey UCT UTC
# Universal US/Alaska US/Aleutian US/Arizona US/Central US/East-Indiana
# US/Eastern US/Hawaii US/Michigan US/Mountain US/Pacific US/Pacific-New US/Samoa
# W-SU WET Zulu
# Type it at the prompt below exactly as it appears above.
script_wait_line "Timezone?"
script_send_line "US/Central"

script_wait_line "You may now reboot your computer by pressing control+alt+delete."
script_set_boot c
script_press_key ctrl-alt-delete

script_wait_line "darkstar login:"
script_send_line root
script_wait_line "darkstar:~#"
script_send_line /retro/autoinst.d/autoconf.sh