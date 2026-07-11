TARGET_DISK=/dev/hda
SWAP_MB=64

# dinstall prepends /dev/ to the partition names it reads, so answer them bare.
SWAP_PARTITION=hda1
LINUX_PARTITION=hda2

FAT_PARTITION=/dev/hdb1
FAT_MOUNT=/retro

NET_HOSTNAME=debra
NET_DOMAINNAME=retro.net
NET_IPADDR=10.0.2.15
NET_NETWORK=10.0.2.0
NET_BROADCAST=10.0.2.255
NET_GATEWAY=10.0.2.2
NET_NETMASK=255.255.255.0
NET_NAMESERVER=10.0.2.3

TIMEZONE=US/Central

# dsetup menu selections. Port 3 is /dev/cua2, where qemu.sh puts the mouse.
MODEM_PORT=5      # no modem
MOUSE_TYPE=1      # serial mouse of any type
MOUSE_PORT=3      # /dev/cua2
MOUSE_PROTOCOL=1  # Microsoft

vga_wait -l "boot:"
kb_send_line ""
vga_wait -l "$SHELL_PROMPT"

serial_shell_start || return 1

# dinstall and dsetup only ever call tput to emit cursor escapes, which would
# litter the serial stream, so replace the binary with a no-op. dsetup reads
# its escapes in a later shell, so shadowing tput through PATH would miss it.
serial_shell_send 'for p in /bin/tput /usr/bin/tput /usr/local/bin/tput; do if [ -f $p ]; then mv $p $p.real; echo exit 0 >$p; chmod 755 $p; fi; done' || return 1

# dinstall's first menu entry runs fdisk interactively, so partition up front
# and skip to initializing the partitions it made.
serial_shell_send --no-wait "fdisk $TARGET_DISK" || return 1
fdisk_partitions "$SWAP_MB" || return 1
serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1

serial_shell_send --no-wait "dinstall" || return 1

serial_prompt "Please select one:" "2"
serial_prompt -r "What is the name of your swap partition" "$SWAP_PARTITION"
serial_prompt "Would you like to check for bad blocks (y/n) [y]?" "n"
serial_prompt "Press <RETURN> to continue..." ""

serial_prompt "Please select one:" "3"
serial_prompt "On which partition do you wish to create an ext2 filesystem?" "$LINUX_PARTITION"
serial_prompt "Would you like to check for bad blocks (y/n) [y]?" "n"
serial_prompt "Press <RETURN> to continue..." ""

serial_prompt "Please select one:" "5"
serial_prompt "Continue with the installation of the base system (y/n) [y]?" "y"

# Mount the root filesystem before continuing; an empty directory answer mounts
# it at /root itself, where the rest of the install expects it.
serial_prompt "or (c)ontinue with the installation:" "m"
serial_prompt "Mount which filesystem (ex: /dev/hda3)? /dev/" "$LINUX_PARTITION"
serial_prompt "Mount /dev/$LINUX_PARTITION on which directory (ex: /usr)? /root/" ""
serial_prompt "or (c)ontinue with the installation:" "c"

# An empty answer takes the default of /dev/fd0.
serial_prompt "Please specify /dev/fd0 or /dev/fd1 [/dev/fd0]: /dev/" ""

serial_wait -l "Please insert basedisk #1 into /dev/fd0 and press <RETURN>:"
script_change_floppy basedsk1
serial_send ""
serial_wait -l "Please insert basedisk #2 into /dev/fd0 and press <RETURN>:"
script_change_floppy basedsk2
serial_send ""

# dinstall hands off to dsetup to configure the installed system.
serial_prompt "Which partition contains your root filesystem? /dev/" "$LINUX_PARTITION"
serial_prompt "Which partition is your swap partition (<RETURN> for none)? /dev/" "$SWAP_PARTITION"
serial_prompt "What is the unqualified hostname of your machine?" "$NET_HOSTNAME"
serial_prompt -r "What is the local domainname" "$NET_DOMAINNAME"
serial_prompt -r "Your fully-qualified hostname is .* Correct \(y/n\)\?" "y"
serial_prompt "Does your machine require additional networking setup (y/n)?" "y"
serial_prompt "What is the IP address of your machine?" "$NET_IPADDR"
serial_prompt "What is your netmask?" "$NET_NETMASK"
serial_prompt "What is your network address?" "$NET_NETWORK"
serial_prompt -r "What is your broadcast address" "$NET_BROADCAST"
serial_prompt "What is your gateway address?" "$NET_GATEWAY"
serial_prompt -r "What is the address of your nameserver" "$NET_NAMESERVER"
serial_prompt "Is this correct (y/n)?" "y"
serial_prompt "Do you have an ethernet connection (y/n)?" "y"

serial_prompt "Is your system clock set to GMT?" "y"
serial_prompt -r "Press <RETURN> for more" ""
serial_prompt "Which timezone?" "$TIMEZONE"
serial_prompt "Load a non-US keymap at boot time (y/n)?" "n"

serial_prompt "Which port contains your modem (if you have one)?" "$MODEM_PORT"
serial_prompt "Which type of mouse do you have (if you have one)?" "$MOUSE_TYPE"
serial_prompt "Which port contains your mouse?" "$MOUSE_PORT"
serial_prompt "What type of serial mouse do you have?" "$MOUSE_PROTOCOL"

# dinstall warns that it installs no boot loader, so run lilo from the shell.
serial_prompt "Would you like to make a custom bootdisk before proceeding (y/n)?" "n"
serial_prompt "Press <RETURN> to continue..." ""

serial_prompt "Please select one:" "7"
serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1

serial_shell_send "mkdir -p $FAT_MOUNT && mount -t msdos $FAT_PARTITION $FAT_MOUNT" || return 1
serial_shell_send "sh $FAT_MOUNT/guestlib.d/deb091/lilo.sh /dev/$LINUX_PARTITION /root" || return 1
serial_shell_send "umount $FAT_MOUNT" || return 1

script_set_boot c
serial_shell_send --no-wait "reboot" || return 1

vga_wait -l "$NET_HOSTNAME.$NET_DOMAINNAME login:"
kb_send_line "root"
vga_wait -l "[root:~]#"
kb_send_line "$INSTALL_POSTINST_COMMAND"
