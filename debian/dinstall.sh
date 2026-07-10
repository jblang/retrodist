# shellcheck shell=bash
# Shared driver for Debian 1.1-1.3 dialog-based dinstall.

TARGET_DISK=/dev/hda
SWAP_MB=64
SWAP_PARTITION=/dev/hda1
LINUX_PARTITION=/dev/hda2

# QEMU exposes qemu.d/fat here; the driver mounts it at FAT_MOUNT so
# dinstall's base-archive search finds /retro/base1_X.tgz on its own.
FAT_PARTITION=/dev/hdb1
FAT_MOUNT=/retro

# The real dialog binary on the install ramdisk, renamed aside to make room
# for the interposer.
DIALOG_BIN=/usr/bin/dialog

# Main menu title: "Debian Linux 1.1 Installation Main Menu" (1.1),
# "Debian GNU/Linux Installation Main Menu" (1.2/1.3).
DINSTALL_MENU='Debian (GNU/)?Linux( [0-9.]+)? Installation Main Menu'

# Keymap for the keyboard step (1.2+); 1.1 sets this empty.
KEYMAP=us

# Debian 1.1 asks about the keyboard inside "Configure the Base System"
# instead of from a main-menu step of its own.
DINSTALL_CONFIG_KEYBOARD=false

# Floppy image to insert before the kernel step; empty keeps the boot floppy
# (1.2/1.3 boot from the rescue floppy dinstall reads the kernel from).
KERNEL_FLOPPY=

# Floppy image for the device driver step; empty reads them from FAT_MOUNT.
DRIVER_FLOPPY=drv1440.bin

# Any path under /usr/lib/zoneinfo (e.g. US/Pacific) works.
TIMEZONE=Etc/UTC

# First boot forces a root password and a user account; passwd wants six or
# more characters from at least two classes, not resembling the username.
ROOT_PASSWORD=password1
USER_NAME=debian
USER_PASSWORD=password1

# Network configuration:
NET_HOSTNAME=debian
NET_DOMAINNAME=retro.net
NET_IPADDR=10.0.2.15
NET_NETWORK=10.0.2.0
NET_BROADCAST=10.0.2.255
NET_GATEWAY=10.0.2.2
NET_NETMASK=255.255.255.0
NET_NAMESERVER=10.0.2.3
NET_MODULE=
NET_MODULE_ARGS=

# Set true on releases whose first boot logs out instead of leaving a root
# shell, so autoconf logs back in.
DINSTALL_RELOGIN=false

# Prompts autoconf waits for; empty takes the defaults in dinstall_autoconf.
DINSTALL_LOGIN_PROMPT=
DINSTALL_PASSWORD_PROMPT=
DINSTALL_SHELL_PROMPT=

# Open a shell on VT2, swap in the dialog interposer, and partition the disk
# up front because dinstall partitions with cfdisk, which cannot be driven.
# Back on VT1, enter answers the color/monochrome menu still on the real dialog.
dinstall_start() {
    screen_wait -l "Select Color or Monochrome"
    kb_press_key alt-f2
    screen_wait -l "Please press Enter to activate this console."
    kb_press_key ret
    screen_wait -l "${SHELL_PROMPT:-#}"
    # The boot kernel ships the serial driver as a module, so mount the FAT
    # partition and insmod the staged serial.o before the serial shell.
    kb_send_line "mkdir -p $FAT_MOUNT; mount -t msdos $FAT_PARTITION $FAT_MOUNT"
    kb_send_line "[ ! -f $FAT_MOUNT/serial.o ] || insmod $FAT_MOUNT/serial.o"
    serial_shell_start || return 1
    serial_shell_send "mv $DIALOG_BIN $DIALOG_BIN.real" || return 1
    serial_shell_send "cp $FAT_MOUNT/autoinst.d/dialog.sh $DIALOG_BIN" || return 1
    serial_shell_send "chmod 755 $DIALOG_BIN" || return 1
    serial_shell_send --no-wait "fdisk $TARGET_DISK" || return 1
    script_fdisk_partitions "$SWAP_MB" || return 1
    serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1
    serial_shell_exit || return 1
    kb_press_key alt-f1
    kb_press_key ret
}

# Choose a main menu step by its displayed item text, tolerating the release
# notes some boot media show first.
dinstall_step() {
    dialog_answer \
        textbox "Release Notes" ok \
        -x menu -r "$DINSTALL_MENU" -d -r "$1"
}

# Take the main menu's "Next" entry, whichever step it currently points at.
dinstall_next() {
    dialog_answer menu -r "$DINSTALL_MENU" Next
}

# Configure the keyboard (1.2+; 1.1 has no keyboard step).
dinstall_keyboard() {
    dinstall_next
    dialog_answer menu "Select Keyboard" "$KEYMAP"
}

# Initialize and activate the swap partition created by fdisk.
dinstall_swap_partition() {
    dinstall_next
    dialog_answer -l "swap partition" \
        menu -r "Select (Disk|Swap) Partition" "$SWAP_PARTITION" \
        yesno "Scan for Bad Blocks?" no \
        -x yesno "Are You Sure?" yes
}

# Initialize the Linux partition and mount it as the root filesystem.
dinstall_root_partition() {
    dinstall_next
    dialog_answer -l "root partition" \
        menu -r "Select (Disk )?Partition" "$LINUX_PARTITION" \
        yesno "Scan for Bad Blocks?" no \
        yesno "Are You Sure?" yes \
        -x yesno "Mount as the Root Filesystem?" yes
}

# Install the base system, either from a medium chosen here or from the
# staged base1_X.tgz that dinstall finds on the FAT mount by itself.
dinstall_base() {
    dinstall_next
    dialog_answer -l "installation medium" \
        menu "Select Installation Medium" -d "already mounted filesystem" \
        inputbox "Choose Debian directory" "$FAT_MOUNT" \
        menu "Select Base Archive file" -d "manually" \
        inputbox "Enter the Base Archive directory" "$FAT_MOUNT" \
        -x menu -r "$DINSTALL_MENU" -n
}

# Install the kernel, and on 1.3 the modules, from the floppy drive or the
# FAT mount.
dinstall_kernel() {
    dinstall_next
    [ -z "$KERNEL_FLOPPY" ] || script_change_floppy "$KERNEL_FLOPPY"
    dialog_answer -l "kernel install" \
        menu "Select Disk Drive" /dev/fd0 \
        -x msgbox "Please Insert Disk" ok \
        menu "Select Installation Medium" -d "already mounted filesystem" \
        inputbox "Choose Debian directory" "$FAT_MOUNT" \
        menu "Select Base Archive file" -d "manually" \
        -x inputbox "Enter the Base Archive directory" "$FAT_MOUNT"
}

# Install the device drivers, from the drivers floppy when one is configured.
dinstall_drivers() {
    dinstall_next
    [ -n "$DRIVER_FLOPPY" ] || return 0
    script_change_floppy "$DRIVER_FLOPPY"
    dialog_answer -l "driver install" \
        menu "Select Disk Drive" /dev/fd0 \
        -x msgbox "Please Insert Disk" ok
}

# Install one modconf module with its arguments and return to the category menu.
dinstall_module() {
    local category=$1 module=$2 args=${3:-}

    dialog_answer -l "$module module" \
        menu "Select Category" "$category" \
        menu -r "Select ($category )? ?modules" "$module" \
        menu -r "Module $module [-+]" Install \
        -x inputbox "Enter Command-Line Arguments" "$args"
    screen_wait -l "Please press ENTER when you are ready to continue."
    kb_press_key ret
    dialog_answer -x menu -r "Select ($category )? ?modules" Exit
}

# Record the network module in modconf, if the release needs one.
dinstall_net_module() {
    dinstall_next
    if [ -n "$NET_MODULE" ]; then
        dinstall_module net "$NET_MODULE" "$NET_MODULE_ARGS"
    fi
    dialog_answer -x menu "Select Category" Exit
}

# Answer 1.1's keyboard question, which reaches the adapter without a TITLE.
dinstall_config_keyboard() {
    serial_wait -l "TITLE: Keyboard Setup"
    serial_wait -l "TYPE: yesno"
    serial_wait -l 'TEXT: a U.S. keyboard?  (If you live in the U.S., you should answer "Yes".)'
    serial_prompt "RESPONSE:" yes
}

# Configure the base system. Its timezone tool (dsetup-tz) is a plain console
# script on VT1, so it is answered with keystrokes rather than over serial.
dinstall_base_config() {
    dinstall_next
    if [ "$DINSTALL_CONFIG_KEYBOARD" = true ]; then
        dinstall_config_keyboard
    fi
    screen_wait -l "Which?"
    kb_send_line "$TIMEZONE"
    screen_wait -r 'Is your system clock set to GMT( \(y/n\) \[y\])?[?]'
    kb_send_line y
}

# Configure TCP/IP with the NET_* values.
dinstall_net() {
    dinstall_next
    dialog_answer -l "network configuration" \
        inputbox "Please enter your Host name" "$NET_HOSTNAME" \
        yesno "Use a Network?" yes \
        inputbox "Please enter your Domain name" "$NET_DOMAINNAME" \
        yesno "Confirm" yes \
        inputbox "Please Enter IP Address" "$NET_IPADDR" \
        inputbox "Please Enter Netmask" "$NET_NETMASK" \
        inputbox "Please Enter Network Address" "$NET_NETWORK" \
        inputbox "Please Enter Broadcast Address" "$NET_BROADCAST" \
        menu "Choose Broadcast Address" -d "Last bits set to one" \
        yesno "Is there a Gateway?" yes \
        inputbox "Please Enter Gateway Address" "$NET_GATEWAY" \
        menu "Locate DNS Server" 2 \
        inputbox "Please Enter Name Server Address" "$NET_NAMESERVER" \
        yesno "Please Confirm" yes \
        -x yesno "Use Ethernet?" yes \
        -x menu "Choose network interface" eth0
}

# Install LILO on the target disk MBR and make Linux the default.
dinstall_lilo() {
    dinstall_next
    dialog_answer -l "LILO installation" \
        yesno "Create Master Boot Record?" yes \
        -x yesno "Make Linux the Default Boot Partition?" yes
}

# Skip the boot floppy, reboot from the hard disk instead.
dinstall_reboot() {
    dinstall_step "Reboot [Tt]he System"
    script_set_boot c
    dialog_answer yesno "Reboot the system?" yes
}

# Run each main menu step as it becomes "Next", matching on the menu's own item
# text so one tree covers all three releases whatever order they run steps in.
dinstall_dispatch() {
    dialog_answer -l "dinstall main menu" \
        textbox "Release Notes" ok \
        menu -r "$DINSTALL_MENU" -i "Next :: Configure the Keyboard" -f dinstall_keyboard \
        menu -r "$DINSTALL_MENU" -i -r "Next :: Initialize and Activate .*Swap" -f dinstall_swap_partition \
        menu -r "$DINSTALL_MENU" -i -r "Next :: Initialize .*Linux.*Partition" -f dinstall_root_partition \
        menu -r "$DINSTALL_MENU" -i "Next :: Install the Base System" -f dinstall_base \
        menu -r "$DINSTALL_MENU" -i -r "Next :: Install .*Kernel" -f dinstall_kernel \
        menu -r "$DINSTALL_MENU" -i "Next :: Install the Device Drivers" -f dinstall_drivers \
        menu -r "$DINSTALL_MENU" -i "Next :: Configure Device Driver Modules" -f dinstall_net_module \
        menu -r "$DINSTALL_MENU" -i "Next :: Configure the Base System" -f dinstall_base_config \
        menu -r "$DINSTALL_MENU" -i "Next :: Configure the Network" -f dinstall_net \
        -x menu -r "$DINSTALL_MENU" -i "Next :: Make Linux Bootable Directly From Hard Disk" -f dinstall_lilo
}

# Answer the root.sh first boot runs on tty1: root password, user account,
# and dselect, which "q" quits straight away.
dinstall_1stboot() {
    # Answered prompts stay on screen, so anchor each passwd run on its
    # unique header and queue both lines; getpass reads them in order.
    screen_wait -l "Changing password for root"
    kb_send_line "$ROOT_PASSWORD"
    kb_send_line "$ROOT_PASSWORD"

    screen_wait -l "Enter a username for your account:"
    kb_send_line "$USER_NAME"
    screen_wait -l "Changing password for $USER_NAME"
    kb_send_line "$USER_PASSWORD"
    kb_send_line "$USER_PASSWORD"

    # adduser runs chfn, whose per-field prompts differ by release, so take the
    # empty default of each until the shared confirmation appears.
    until screen_wait -t 0.1 -r "^Is (the|this finger) information correct\?? \[y/n\]\??"; do
        kb_press_key ret
    done
    kb_send_line y

    # Only some releases offer shadow passwords before dselect, so poll for
    # both, and answer the offer once: taking it leaves the prompt on screen.
    local shadow_offered=false
    until screen_wait -t 1 -l "Press <ENTER> to continue:"; do
        if [ "$shadow_offered" = false ] &&
            screen_wait -t 0.1 -l "Shall I install shadow passwords? [Y/n]"; then
            kb_send_line y
            shadow_offered=true
        fi
    done
    kb_press_key ret
    screen_wait -l \
        "Debian Linux \`dselect' package handling frontend." \
        "6. [Q]uit        Quit dselect." \
        "Press ENTER to confirm selection.   ^L to redraw screen."
    kb_press_key q
    kb_press_key ret
}

# Run the staged autoconfiguration script once root.sh hands back a shell. The
# prompt is matched as a regex because PS1 is "\h\$", which renders as a bare
# "#" until the hostname is set and as "HOST#" afterward.
dinstall_autoconf() {
    local login_prompt password_prompt shell_prompt
    login_prompt=${DINSTALL_LOGIN_PROMPT:-"$NET_HOSTNAME login:"}
    password_prompt=${DINSTALL_PASSWORD_PROMPT:-"Password:"}
    shell_prompt=${DINSTALL_SHELL_PROMPT:-'^[^[:space:]]*# *$'}

    screen_wait -l "Have fun!"
    if [ "$DINSTALL_RELOGIN" = true ]; then
        screen_wait -l "$login_prompt"
        kb_send_line root
        screen_wait -l "$password_prompt"
        kb_send_line "$ROOT_PASSWORD"
    fi
    screen_wait -r "$shell_prompt"
    kb_send_line "$SCRIPT_AUTOCONF_COMMAND"
}

# Drive the full dinstall sequence, first boot, and autoconf.
dinstall_setup() {
    dinstall_start
    dinstall_dispatch
    dinstall_reboot
    dinstall_1stboot
    dinstall_autoconf
}
