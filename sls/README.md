# Softlanding Linux System

[Softlanding Linux System (SLS)](https://en.wikipedia.org/wiki/Softlanding_Linux_System) was one of the first Linux distributions. It was created by Peter MacDonald and packaged Linux with an installer, package tools, X, networking, compilers, and userland utilities.

## Release History

This table summarizes the SLS releases currently scripted in this repo. The data comes from release notes and changelogs included with the source media.

| Release | Date | SLS version | Kernel | C library | Compiler | X |
| --- | --- | --- | --- | --- | --- | --- |
| [0.98](./0.98/README.txt) | [1992-10](./0.98/ChangeLog.txt) | .98 | 0.98p1 | - | gcc/g++ | X11 |
| [0.99p2](./0.99p2/README.txt) | 1993-03 | .99p2 | 0.99p4 | libc 4.2/4.3 | gcc 2.3.3 | XFree 1.2 |

## Milestones

- SLS provided one of the earliest broadly usable Linux installation flows, with boot/root floppies, `doinstall`, `sysinstall`, and package series that could be installed selectively.
- SLS organized packages into lettered disk series: `a` for the base system, `b` for extras, `c` for compilers, and `x` for X.
- The 0.99p2 release notes describe a large refresh of the base, compiler, and X series, including shared-library updates, System V init, LILO, TCP/IP setup improvements, and XFree 1.2.

## Historical Background

- [Wikipedia article](https://en.wikipedia.org/wiki/Softlanding_Linux_System)
- SLS influenced early Slackware; Slackware began as a patched and repackaged SLS-derived distribution before replacing the SLS installer and package tools.

## Installation

Run a scripted install when the selected variant includes `script.sh`:

```sh
retro install sls/VERSION/VARIANT
```

For example:

```sh
retro install sls/0.99p2/oldlinux
```

For the original manual install flow, use `retro boot` and follow the release's
own instructions. When prompted to change disks, use `qmp change-image`.
