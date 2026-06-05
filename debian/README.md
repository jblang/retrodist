# Debian

[Debian](https://www.debian.org/) was established in August 1993 by Ian Murdock, who published a [manifesto](https://www.debian.org/doc/manuals/project-history/manifesto.en.html) outlining the project's goals. Like Slackware, it was created out of frustration with the bugs in SLS.  More historical information is on [Wikipedia](https://en.wikipedia.org/wiki/Debian). 

## Release History

This table summarizes the early Debian releases represented in this repo.

| Release | Variant | Date | Codename |
| --- | --- | --- | --- |
| 0.91 | Infomagic | January 1994 | - |
| 0.93R6 | official | Late 1995 | - |
| 1.1 | official | June 1996 | Buzz |
| 1.2 | official | December 1996 | Rex |
| 1.3 | official | July 1997 | Bo |

## Installation

For Debian variants that include `script.sh`, run the scripted install from the repo root:

```sh
retro install debian/VERSION/VARIANT
```

For example:

```sh
retro install debian/1.2/official
```

`retro install` starts QEMU, uses the variant's `script.sh` to handle installer prompts and run `/retro/autoinst`, then switches the next boot to the hard disk for the final reboot. After the installer and post-install configuration finish, the VM will reboot into the installed system.

If you want the original manual install flow instead, use the `retro boot` command and follow the original installation instructions for the version you are installing. When prompted to change disks, use the `qmp change-floppy` command to mount the required image.

## Version Notes

- `0.91`: Fully scripted, including post-boot package installation and configuration.
- `0.93R6`: Automatic installation is currently blocked because the installer kernel cannot mount the staged MSDOS install disk exposed as `/dev/hdb1`.
- `1.1`: Uses the default QEMU NE2000 ISA NIC.
- `1.2` and `1.3`: Use the kernel's built-in PCnet driver for the default QEMU PCI NIC.

For implementation details on the shared Debian installer scripts, see [autoinst/install/README.md](../autoinst/install/README.md).
