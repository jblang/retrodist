# Softlanding Linux System

[Softlanding Linux System (SLS)](https://en.wikipedia.org/wiki/Softlanding_Linux_System) was one of the first Linux distributions. It was created by Peter MacDonald and packaged Linux with an installer, package tools, X, networking, compilers, and userland utilities.

## Release History

This table summarizes the SLS releases currently scripted in this repo. The data comes from release notes and changelogs included with the source media.

| Release | Date | SLS version | Kernel | C library | Compiler | X |
| --- | --- | --- | --- | --- | --- | --- |
| [1992.11](./1992.11/neozeede/README.txt) | [1992-11](./1992.11/neozeede/ChangeLog.txt) | .98 | 0.98p1 | - | gcc/g++ | X11 |
| [1993.03](./1993.03/princeton/extract.d/install/install/README) | [1993-03](./1993.03/princeton/extract.d/install/install/HISTORY) | .99p2 | 0.99p4 | libc 4.2/4.3 | gcc 2.3.3 | XFree 1.2 |

## Milestones

- SLS provided one of the earliest broadly usable Linux installation flows, with boot/root floppies, `doinstall`, `sysinstall`, and package series that could be installed selectively.
- SLS organized packages into lettered disk series: `a` for the base system, `b` for extras, `c` for compilers, and `x` for X.
- The 1993.03 release notes describe a large refresh of the base, compiler, and X series, including shared-library updates, System V init, LILO, TCP/IP setup improvements, and XFree 1.2.

## Historical Background

- [Wikipedia article](https://en.wikipedia.org/wiki/Softlanding_Linux_System)
- SLS influenced early Slackware; Slackware began as a patched and repackaged SLS-derived distribution before replacing the SLS installer and package tools.

## Installation

For SLS variants that include `script.sh`, run the scripted install from the repo root:

```sh
retro install sls/VERSION/VARIANT
```

For example:

```sh
retro install sls/1993.03/princeton
```

`retro install` starts QEMU, uses the variant's `script.sh` to handle the SVGA prompt, root-disk swap, `/retro/autoinst`, fdisk reboot, boot-floppy write, and final reboot. After the installer finishes, the VM will reboot into the installed system.

If you want the original manual install flow instead, use the `retro boot` command and follow the original installation instructions for the version you are installing. When prompted to change disks, use the `qmp change-floppy` command to mount the required image.
