# Debian

[Debian](https://www.debian.org/) was established in August 1993 by Ian Murdock,
who published a
[manifesto](https://www.debian.org/doc/manuals/project-history/manifesto.en.html)
outlining the project's goals. Like Slackware, it was created out of frustration
with the bugs in SLS. More historical information is available on
[Wikipedia](https://en.wikipedia.org/wiki/Debian).

## Release History

This table summarizes the early Debian releases represented in this repo.

| Release | Variants | Date | Codename |
| --- | --- | --- | --- |
| 0.91 | Infomagic | January 1994 | - |
| 1.1 | official, Infomagic | June 1996 | Buzz |
| 1.2 | official, Infomagic | December 1996 | Rex |
| 1.3 | official, Infomagic | July 1997 | Bo |

## Installation

Run a scripted install when the selected variant's `config.toml` selects an
installer driver:

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

- `0.91`: Installs a serial mouse on `/dev/cua2`, configured for X11.
- `1.1`: Uses a QEMU NE2000 ISA NIC, loaded as the `ne` module.
- `1.2` and `1.3`: Use the kernel's built-in PCnet driver for the default QEMU PCI NIC.

## Installer Automation

Every release is installed by driving its own `dinstall` from the host. The
disk is partitioned beforehand, because otherwise `dinstall` shells out to an
interactive `fdisk` or `cfdisk`.

`1.1` through `1.3` use a dialog-based `dinstall`. The guest's `dialog` binary
is replaced with the serial adapter, so every installer screen is answered over
the serial port. The shared Python driver is
[`hostlib/installers/debian.py`](../hostlib/installers/debian.py). It
walks the main menu by matching its `Next` entry, so one menu tree covers all
three releases while each `config.toml` supplies only release-specific options.
The host then scripts Debian's installed-system setup (root password, user
account, and `dselect`) before running the configured post-install stages.

`0.91`'s `dinstall` is a prompt-and-response shell script, so its declarative
`prompt-sequence` in [config.toml](0.91/infomagic/config.toml) answers it over
the serial shell, replacing `tput` with a no-op first so prompts arrive as plain
lines. That `dinstall` installs no boot loader and no packages, so two
standalone scripts in [../guestlib/deb091](../guestlib/deb091) fill the gaps.
They take arguments rather than reading the install environment:

- `lilo.sh ROOTDEV ROOTMOUNT`: runs `rdev` on the installed kernel, rewrites
  `lilo.conf`, and installs LILO. The prompt sequence runs it once `dinstall`
  exits.
- `pkginst.sh INSTALL_D`: installs every `.deb` under `$INSTALL_D/packages` with
  `zcat | cpio`, runs `fixperms` when metadata is present, then runs the
  non-interactive `.inst` scripts from `/var/adm/dpkg/inst`. Run from
  the custom post-install stage.
