# Red Hat Linux

These configs stage and boot early Intel Red Hat Linux releases, covering the
pre-RHEL line from Red Hat Commercial Linux 1.1 through Red Hat Linux 6.1.

## Release Matrix

This table summarizes the Red Hat releases represented in this repo and their
current automation status.

| Release | Name | Automation |
| --- | --- | --- |
| [1.1](./1.1/README.txt) | Mother's Day + 0.1 | Manual install; not working |
| [2.1](./2.1/README.txt) | Red Hat Linux 2.1 | Scripted UI install |
| [3.0.3](./3.0.3/README.txt) | Red Hat Linux 3.0.3 | Scripted UI install |
| [4.0](./4.0/README.txt) | Colgate | Scripted UI install |
| [4.1](./4.1/README.txt) | Vanderbilt | Scripted UI install |
| [4.2](./4.2/README.txt) | Biltmore | Scripted UI install |
| [5.0](./5.0/README.txt) | Hurricane | Scripted UI install |
| [5.1](./5.1/README.txt) | Manhattan | Scripted UI install |
| [5.2](./5.2/README.txt) | Apollo | Kickstart install |
| [6.1](./6.1/README.txt) | Cartman | Manual install; not working |

## Historical Background

- [Wikipedia article](https://en.wikipedia.org/wiki/Red_Hat_Linux)
- [Red Hat Linux](https://en.wikipedia.org/wiki/Red_Hat_Linux) was the
  community Linux distribution line that preceded Red Hat Enterprise Linux.

## Installation

Run a scripted install when the selected version has a working `script.sh`:

```sh
retro install redhat/VERSION/VARIANT
```

For example:

```sh
retro install redhat/5.2/VARIANT
```

For the original manual install flow, use `retro boot` and follow the release's
own installer prompts:

```sh
retro boot redhat/VERSION/VARIANT
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

The `script.sh` files are host-side QMP scripts. They wait for installer screen
text, send keys or boot commands, and change floppy images when the installer
asks for another disk.

The older Red Hat installers are less uniform than Slackware's setup scripts:

- 1.1 through 3.0.3 use boot/root/ramdisk floppy handoffs before the installer
  can continue from CD-ROM.
- 4.0 through 5.1 are driven through the text UI, including partitioning,
  package group selection, X11 setup, networking, LILO, and reboot.
- 5.2 uses the installer Kickstart support instead of driving every screen.
- 6.1 currently boots the text installer from the CD-ROM media; Kickstart is
  not configured for it.

After installation, each scripted version's `autoconf.sh` runs first-boot
configuration. The autoconf launch checks whether the staged FAT disk is already
available at `/retro` and mounts it when needed. The later versions set
`X11_CHIPSET=clgd5446` to match the emulated Cirrus Logic video hardware.

## Known Issues

- Red Hat 1.1 manual installation currently fails during package installation.
- Red Hat 5.0 and 5.1 claim to support Kickstart on their LILO boot screens,
  but this has not worked reliably here, so those versions use UI-driving
  scripts instead.
- Red Hat 6.1 graphical installation is illegibile under QEMU's Cirrus Logic
  emulation. Use text mode. After installation, it won't boot due to IDE
  contoller interrupt errors.
