# Slackware 1.1.1

Slackware 1.1.1 was released in December 1993 based on the kernel compilation date and file timestamps. Refer to the [README](./infomagic/README.txt) from the CD-ROM for details of the release.

## Variants

### infomagic

This `infomagic` variant was taken from the December 1993 [InfoMagic Linux Developer's Resource](../../../cdrom/infomagic/ldr/README.md) CD-ROM.

## Automatic Installation

Automatic installation is supported for this release.

Log in as `root` when prompted. Ignore the rest of the installer instructions and enter the following instead:

```sh
mount -t msdos /dev/hdb1 /mnt
/mnt/autoinst
```

- The scripts will partition and format the disk, install the base system and selected package sets, configure the installed system, and reboot when complete.
- After the final reboot, you should have a fully installed Slackware 1.1.1 system with the repo's standard serial-console, networking, and X configuration.

## Manual Installation

If you want the original Slackware 1.1.1 installation flow instead:

- Read the instructions shown before the login prompt and log in as `root`.
- Partition the hard disk, initialize swap, and format the root partition.
- Use the stock installer tools from the boot/root environment and install from the staged MSDOS partition on `/dev/hdb1`.
- If you are manually recreating the repo's install setup, mount the staged source disk at `/mnt`.
