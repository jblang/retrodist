# Red Hat Linux

These configs stage and boot early Intel Red Hat Linux releases, covering the
pre-RHEL line from Red Hat Commercial Linux 1.1 through Red Hat Linux 6.1.

## Release Matrix

This table summarizes the Red Hat releases represented in this repo and their
current automation status.

| Release | Codename | Automation |
| --- | --- | --- |
| [1.1](./1.1-infomagic/README.txt) | Mother's Day + 0.1 | Scripted install; package installation fails |
| [2.1](./2.1-infomagic/README.txt) | Bluesky | Scripted UI install |
| [3.0.3](./3.0.3-infomagic/README.txt) | Picasso | Scripted UI install |
| [4.0](./4.0-infomagic/README.txt) | Colgate | Scripted UI install |
| [4.1](./4.1-infomagic/README.txt) | Vanderbilt | Scripted UI install |
| [4.2](./4.2-infomagic/README.txt) | Biltmore | Scripted UI install |
| [5.0](./5.0-infomagic/README.txt) | Hurricane | Scripted UI install |
| [5.1](./5.1-infomagic/README.txt) | Manhattan | Scripted UI install |
| [5.2](./5.2-infomagic/README.txt) | Apollo | Kickstart install |
| [6.1](./6.1-infomagic/README.txt) | Cartman | Scripted text install; installed system does not boot |

## Historical Background

- [Wikipedia article](https://en.wikipedia.org/wiki/Red_Hat_Linux)
- [Red Hat Linux](https://en.wikipedia.org/wiki/Red_Hat_Linux) was the
  community Linux distribution line that preceded Red Hat Enterprise Linux.

## Installation

Run a scripted install when the selected version contains `install.sh`:

```sh
retro install redhat/VERSION-infomagic
```

For example:

```sh
retro install redhat/5.2-infomagic
```

For the original manual install flow, use `retro boot` and follow the release's
own installer prompts:

```sh
retro boot redhat/VERSION-infomagic
```

When prompted to change floppy disks, use `qmp change-image IMAGE`. Early
versions need this during boot:

```sh
qmp change-image ramdisk1.img
qmp change-image ramdisk2.img
qmp change-image rootdisk.img
qmp change-image boot.img
```

## Kickstart

If a Red Hat config or version directory contains `ks.cfg`, `retro extract`
copies a comment-stripped and empty-line-stripped copy into the root of the
staged boot floppy image as `ks.cfg`.

Red Hat 5.2 currently provides a Kickstart file. Its install script boots with:

```sh
linux ks=floppy
```

Kickstart staging only modifies an existing `boot.img`; it does not create a
separate Kickstart floppy.

## Scripted Installs

The `install.sh` files are host-side QMP scripts. They wait for installer screen
text, send keys or boot commands, and change floppy images when the installer
asks for another disk.

The older Red Hat installers are less uniform than Slackware's setup scripts,
but they now share driver blocks by installer family:

- `perl-install.sh` covers the 1.1 through 3.0.3 Perl/dialog-based era. It
  handles boot/root/ramdisk floppy handoffs and the common partitioning,
  networking, X11, LILO, and reboot prompts used by 2.1 and 3.0.3. Version-only
  package series and startup prompts stay in each release's `install.sh`.
- `c-install.sh` covers the 4.0 through 5.1 C-based text installer era. Version
  `install.sh` files set prompt-order flags and compose the common blocks with
  release-specific partitioning, package component, and X11 prompt sequences.
- 5.2 uses the installer Kickstart support instead of driving every screen.
- 6.1 currently boots the text installer from the CD-ROM media; Kickstart is
  not configured for it.

After installation, each scripted version runs `postinst.sh`. Its launcher
mounts the staged FAT disk at `/retro` when needed. Later versions set
`X11_CHIPSET=clgd5446` to match the emulated Cirrus Logic video hardware.

## Known Issues

- Red Hat 1.1 manual installation currently fails during package installation.
- Red Hat 5.0 and 5.1 claim to support Kickstart on their LILO boot screens,
  but this has not worked reliably here, so those versions use UI-driving
  scripts instead.
- Red Hat 6.1 graphical installation is illegibile under QEMU's Cirrus Logic
  emulation. Use text mode. After installation, it won't boot due to IDE
  contoller interrupt errors.
