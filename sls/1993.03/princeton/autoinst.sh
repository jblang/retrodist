PATH=$PATH:/retro/bin

ROOTFS=ext
FDISK_REBOOT=1

DISK_SWAP_MB=64
disk_init

SLS_INSTALL_MODE=all
sls_sysinstall
make_boot_floppy
