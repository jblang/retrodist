# Slackware 2.1.0

Slackware 2.1.0 was included on the December 1994 InfoMagic Linux Developer's Resource CD-ROM. Refer to the [README](./infomagic/README.txt) from the CD-ROM for details of the release.

## Variants

### infomagic

This `infomagic` variant uses the December 1994 LDR CD set.

## Automatic Installation

Automatic installation is configured for this release.

Boot the VM normally. When the kernel asks for the root disk, switch `floppy0`
to the staged `root.img` in the QEMU monitor. Press `C-a c` in the terminal
(not the emulator window) to access the console, then type:

```text
change floppy0 root.img
```

Then:

- press `Enter` at the first prompt
- ignore the misleading floppy I/O error
- press `Enter` again at the second prompt

The system should finish booting to a root shell.

Once you are logged in as `root`, ignore the stock installer flow and enter:

```sh
mount -t msdos /dev/hdb1 /mnt
/mnt/autoinst
```

- The automated path uses the shared Slackware `2.0+` `pkgtool` wrapper under [autoinst/slakware/pkginst/200.sh](/Users/jblang/repos/retrodist/autoinst/slakware/pkginst/200.sh).
- Refer to [config.sh](./infomagic/config.sh) for the package sets and serial/network defaults used by the automated flow.

## Manual Installation

If you want the original Slackware 2.1.0 installer flow instead:

- boot with the extracted `boot.img` and `root.img`
- in QEMU, swap the root disk into `floppy0` using `change floppy0 root.img`
- press `Enter` at the first prompt and again at the second prompt if you see the misleading floppy error
- log in as `root`
- partition the hard disk, initialize swap, and format the root partition
- run the stock `setup` flow and install from the staged MSDOS partition on `/dev/hdb1`
