# shellcheck shell=bash
# Shared serial driver for Slackware releases that use the SLS doinstall.
# Prompt text follows reference/slackware/1.01/text/doinstall.

TARGET_DISK=/dev/hda
SWAP_MB=64
SWAP_PARTITION=/dev/hda1
# Linux 0.99 mkswap requires an explicit block count. Keep it just below the
# partition created by fdisk's +64M size so cylinder rounding cannot overrun it.
SWAP_BLOCKS=64000
LINUX_PARTITION=/dev/hda2

FAT_PARTITION=/dev/hdb1
BOOTDISK_IMAGE=bootdisk.img
SLACKWARE_SYSINSTALL_PACKAGE_MODE_PROMPT='^Do you want to be prompted before packages are installed\? \(y/n\):'
SLACKWARE_SYSINSTALL_MODEM_PROMPT='^[Dd]o you have a modem \(y/n\)\?'
SLACKWARE_SYSINSTALL_MOUSE_PROMPT='^[Dd]o you have a mouse \(y/n\)\? *$'

# Select the fullest doinstall mode supported by the staged media.
slackware_sysinstall_type() {
    if [ -d fat/install/x1 ]; then
        if [ -d fat/install/t1 ]; then
            echo 3 # Slackware A + X + TeX
        else
            echo 2 # Slackware A + X
        fi
    else
        echo 1 # Slackware A
    fi
}

# Insert a disposable floppy for doinstall's mandatory boot-disk creation.
slackware_sysinstall_bootdisk() {
    : >"$BOOTDISK_IMAGE" || return 1
    truncate -s 1440k "$BOOTDISK_IMAGE" || return 1
    script_change_floppy "$BOOTDISK_IMAGE"
}

# Accept every optional package until doinstall hands off to syssetup. When
# running from /dev/ram, put a disposable floppy in before boot-disk creation.
slackware_sysinstall_packages() {
    local status

    while :; do
        serial_wait_alternative -r \
            "^Install package " \
            "^Insert the disk and press <return> :" \
            "$SLACKWARE_SYSINSTALL_MODEM_PROMPT" \
            "$SLACKWARE_SYSINSTALL_PACKAGE_MODE_PROMPT"
        status=$?
        case $status in
        0) serial_send "y" || return 1 ;;
        1)
            slackware_sysinstall_bootdisk || return 1
            serial_send "" || return 1
            ;;
        2) serial_send "n" || return 1; break ;;
        3) serial_send "n" || return 1 ;;
        *) return "$status" ;;
        esac
    done
}

# Partition and format the disk, then drive the original doinstall/syssetup.
slackware_sysinstall() {
    local install_type

    install_type=$(slackware_sysinstall_type) || return 1

    screen_wait -l "darkstar login:"
    kb_send_line "root"
    # shellcheck disable=SC2034 # Read by serial_shell_start.
    SHELL_PROMPT="darkstar:/#"
    serial_shell_start || return 1

    serial_shell_send --no-wait "fdisk $TARGET_DISK" || return 1
    script_fdisk_partitions "$SWAP_MB" || return 1
    serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1

    serial_shell_send "mkswap $SWAP_PARTITION $SWAP_BLOCKS" || return 1
    serial_shell_send "swapon $SWAP_PARTITION" || return 1
    serial_shell_send "mke2fs $LINUX_PARTITION" || return 1
    serial_shell_send --no-wait "doinstall $LINUX_PARTITION" || return 1

    serial_prompt "Where will you be installing Linux from?" "2"
    serial_prompt \
        "Enter the partition that the source is on (eg. /dev/hda1):" \
        "$FAT_PARTITION"
    serial_prompt \
        "Enter the type of the filesystem (minix/ext2/msdos)" \
        "msdos"
    serial_prompt "Enter type of install (1 or 2):" "$install_type"

    slackware_sysinstall_packages || return 1
    serial_prompt -r "$SLACKWARE_SYSINSTALL_MOUSE_PROMPT" "n"
    serial_prompt \
        "LILO (Linux Loader) Installation:" \
        "Which option would you like? (1/2/3):" "2"

    serial_wait -l "Installation is complete."
    serial_wait -l "${SERIAL_SHELL_PROMPT:-#}" >/dev/null || return 1

    # Stock doinstall only records mounted filesystems. Add the swap and proc
    # entries that the previous in-guest installer supplied automatically.
    serial_shell_send \
        "echo '$SWAP_PARTITION none swap sw 0 0' >> /root/etc/fstab" || return 1
    serial_shell_send \
        "echo 'none /proc proc defaults 0 0' >> /root/etc/fstab" || return 1

    script_set_boot c
	kb_press_key ctrl-alt-delete

    screen_wait -l "darkstar login:"
    kb_send_line "root"
    screen_wait -l "darkstar:/#"
    kb_send_line "$SCRIPT_AUTOCONF_COMMAND"
}
