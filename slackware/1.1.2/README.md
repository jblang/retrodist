# Slackware 1.1.2

Slackware 1.1.2 was released circa **February 1994**. Refer to the [README](./official/README.txt) from the CD-ROM for details of the release.

## Variants

### official

The `official` variant wasobtained from the historical Slackware mirror.

## Automatic Installation

Automatic installation is supported for this release.

Boot the VM normally. When the kernel asks for the root disk, switch `floppy0` to the staged `root.img` in the QEMU monitor. Press `C-a c` in the terminal (not the emulator window) to access the console, then type:

```text
change floppy0 root.img
```

Then:

- press `Enter` at the first prompt
- ignore the misleading floppy I/O error
- press `Enter` again at the second prompt

The system should finish booting to a root shell.

Once you are logged in as `root`, ignore the stock installer prompts and run:

```sh
mount -t msdos /dev/hdb1 /mnt
/mnt/autoinst
```

After the installer and post-install configuration finish, the VM will reboot into the installed system.

## Manual Installation

If you want the original Slackware 1.1.2 installation flow instead:

- boot with the `bareboot` kernel disk and `tty144` root disk
- in QEMU, swap the root disk into `floppy0` using `change floppy0 root.img`
- press `Enter` at the first prompt and again at the second prompt if you see the misleading floppy error
- log in as `root`
- partition the hard disk, initialize swap, and format the root partition
- use the stock installer tools from the boot/root environment and install from the staged MSDOS partition on `/dev/hdb1`
