# Debian

[Debian](https://www.debian.org/) was established in August 1993 by Ian Murdock, who published a [manifesto](https://www.debian.org/doc/manuals/project-history/manifesto.en.html) outlining the project's goals. Like Slackware, it was created out of frustration with the bugs in SLS.  More historical information is on [Wikipedia](https://en.wikipedia.org/wiki/Debian). 

## Release History

This table summarizes the early Debian releases represented in this repo.

| Release | Variants | Date | Codename |
| --- | --- | --- | --- |
| 0.91 | Infomagic | January 1994 | - |
| 1.1 | official, Infomagic | June 1996 | Buzz |
| 1.2 | official, Infomagic | December 1996 | Rex |
| 1.3 | official, Infomagic | July 1997 | Bo |

## Installation

Run a scripted install when the selected variant includes `script.sh`:

```sh
retro install debian/VERSION/VARIANT
```

For example:

```sh
retro install debian/1.2/official
```

For the original manual install flow, use `retro boot` and follow the release's
own instructions. When prompted to change disks, use `qmp change-image`.

## Version Notes

- `0.91`: Fully scripted, including post-boot package installation and configuration.
- `1.1`: Uses a QEMU NE2000 ISA NIC.
- `1.2` and `1.3`: Use the kernel's built-in PCnet driver for the default QEMU PCI NIC.

For implementation details on the shared Debian installer scripts, see [autoinst/install/README.md](../autoinst/install/README.md).
