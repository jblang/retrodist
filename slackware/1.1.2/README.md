# Slackware 1.1.2

Slackware 1.1.2 was released circa **February 1994**. Refer to the [README](./official/README.txt) from the CD-ROM for details of the release.

## Variants

### official

The `official` variant wasobtained from the historical Slackware mirror.

## Automatic Installation

Automatic installation is supported for this release.

Boot the VM normally. When the kernel asks for the root disk, switch floppies in the QEMU monitor. Press C-a c in the terminal (not the emulator window) to access the console, then type the following commands:

```text
eject floppy1
change floppy0 /Users/jblang/repos/retrodist/slackware/1.1.2/official/.extract/root.img
```

Then:

- press `Enter` at the first prompt
- ignore the misleading floppy I/O error
- press `Enter` again at the second prompt

The system should finish booting to a root shell.

Once you are logged in as `root`, ignore the stock installer prompts and run:

```sh
mount -t msdos /dev/hdb1 /var/adm/mount
/var/adm/mount/autoinst
```

After the installer and post-install configuration finish, the VM will reboot into the installed system.

## Manual Installation

If you want the original Slackware 1.1.2 installation flow instead:

- boot with the `bareboot` kernel disk and `color144` root disk
- in QEMU, swap the root disk into `floppy0` using the monitor sequence above
- press `Enter` at the first prompt and again at the second prompt if you see the misleading floppy error
- log in as `root`
- partition the hard disk, initialize swap, and format the root partition
- use the stock installer tools from the boot/root environment and install from the staged MSDOS partition on `/dev/hdb1`