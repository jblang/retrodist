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

- `0.91`: Installs a serial mouse on `/dev/ttyS2`, configured for X11.
- `1.1`: Uses a QEMU NE2000 ISA NIC, loaded as the `ne` module.
- `1.1` through `1.3`: Install the configured X11 package set and use a serial
  mouse on `/dev/ttyS2`.
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

The optional `packages` post-install stage installs declaratively selected
priorities, per-section priorities, and named packages with their dependencies.
See [CONTRIBUTING.md](../CONTRIBUTING.md#debian-package-selection) for index
parsing and CD-ROM or VFAT package-media configuration.

`0.91`'s `dinstall` is a prompt-and-response shell script. Its declarative
`prompt-sequence` in [config.toml](0.91/infomagic/config.toml) matches the stock
VGA screens and types answers through QMP, leaving `tput` and the visible
installer display intact. Only the shared partitioning step uses the automation
serial port while `dinstall` is active. That `dinstall` installs no boot loader
and no packages, so the prompt sequence runs the LILO commands in a serial shell
after installation. The variant's custom
[postinst.sh](0.91/infomagic/postinst.sh) installs every `.deb` under
`/retro/packages` with `zcat | cpio`, runs `fixperms` when metadata is present,
then runs the non-interactive `.inst` scripts from `/var/adm/dpkg/inst`.
