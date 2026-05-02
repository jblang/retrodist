# Slackware Autoinstall Scripts

This directory contains the Slackware-specific install helpers used by `autoinst.sh`.

## Layout

- `sysinst/default.sh`
  Shared installer for the early SLS-style `sysinstall` based Slackware releases.

- `pkginst/111.sh`
  Wrapper for Slackware `1.1.1` `pkgtool`.

- `pkginst/112+.sh`
  Wrapper for the Slackware `1.1.2+` `pkgtool` family.

- `pkginst/shared.sh`
  Common helper used by the `pkgtool` wrappers.

## Package Skips

Slackware `pkgtool` installs can define per-distribution package skips in
`pkgskip.txt` next to each distro's `config.sh`. During extraction, `retro`
generates tagfiles from the package directories and marks every package listed
in `pkgskip.txt` as `SKP`.

## Compatibility Note

The staged install disk is mounted as plain DOS on some historical Slackware installers.
This helper tree therefore uses `slakware/` instead of `slackware/` so the staged path
fits within DOS 8.3 filename limits.

## Original Installers

The Slackware automation in this directory follows two installer families.

### Slackware 1.01

Slackware `1.01` uses the older `doinstall` plus `sysinstall` flow inherited from SLS.

1. `doinstall` starts by asking where the software will come from: floppy, hard disk, tape, CD-ROM, or NFS. It also asks for a broad install type such as base only, base plus X, or base plus X and TeX, so the rest of the install knows which package groups to process.
2. It mounts the target root partition, mounts any extra partitions passed on the command line, creates the install bookkeeping directories, and starts a temporary `fstab`. This is the point where it turns the chosen partitions into a usable target filesystem tree.
3. If a previous `/root/doinst.sh` exists, it runs that script before the bulk package phase. That gives the target system a chance to apply any earlier local setup before new packages are unpacked.
4. `doinstall` then hands control to `sysinstall`, passing along the chosen source, target root, and install mode.
5. `sysinstall` mounts each source disk or source directory, checks that the expected disk marker is present, and walks the package files on that source. Its job is to manage media changes and keep the package stream aligned with the install type that was selected.
6. For each selected package, `sysinstall` unpacks the archive into the target root, records the installed file list, and saves any package post-install script. Those file lists become the install database for later removal or inspection.
7. If a package contains `install/doinst.sh`, `sysinstall` runs it immediately so the package can do its own post-install work, such as moving files into final locations or finishing package-local setup.
8. After the package pass, `doinstall` writes the finished `/etc/fstab` and leaves the new system staged for later boot setup. Compared with later Slackware releases, this flow stops earlier and leaves more of the machine-specific boot configuration outside the guided installer itself.

This is the family handled by `sysinst/default.sh`.

### Slackware 1.1.1 and later text setup

Slackware `1.1.1` and later move to the `setup`/`pkgtool` installer family. In these releases, `setup` or `setup.tty` drives the session and `pkgtool` or `pkgtool.tty` performs the package installation.

1. `setup.tty` begins with environment checks. It decides whether the target is already mounted, prepares its temporary mount area, and on a fresh install can remap the keyboard before touching the target disks.
2. It distinguishes between a clean install and adding software to an existing mounted system. That choice changes whether it needs to build the target layout from scratch or work within an existing filesystem tree.
3. It detects swap partitions, optionally initializes them, enables swap, and starts building `/etc/fstab`. This is where the installer begins committing to the final disk layout of the machine.
4. It selects the root partition, can format it, mounts it on `/mnt`, and can add more Linux partitions at chosen mount points. In practice this step converts the raw partition selection into the mounted directory tree that the packages will populate.
5. It can also append DOS or HPFS partitions to `fstab`. Those are convenience mounts for mixed-system machines and are carried forward into the installed system even though they are not needed to complete the package install.
6. After the target filesystem layout is ready, it asks for the Slackware package source and prepares the chosen source path or device. Depending on the release, that can mean floppy media, a hard-disk path, an already-mounted directory, NFS, or CD-ROM.
7. It selects the package series and calls `pkgtool.tty`. The series choice is the installer's main high-level software selection step.
8. `pkgtool.tty` reads the `TAGFILE`s, mounts source media when needed, installs the selected package archives into the target root, stores package manifests under `/var/adm/packages`, and saves install scripts under `/var/adm/scripts`. The same tool also supports later package removal, so this metadata is meant to survive beyond the install session.
9. When package installation is finished, `setup.tty` completes `/etc/fstab`, records the root device, and switches into the guided post-install configuration phase.
10. The post-install phase usually starts with boot preparation. Depending on the release, this can include creating a boot floppy, configuring LILO, and in later versions copying or selecting a kernel image so the installed system can boot without depending on the original install media.
11. It then moves through machine-specific configuration prompts. The scripts typically ask about modem and mouse setup, timezone selection, hostname and domain name, and the basic TCP/IP settings needed to bring up the machine on first boot.
12. In later releases, some tail-end configuration can be delegated to helper scripts under `/var/adm/setup`, but the purpose is the same: leave the installed system with working boot settings, a populated `fstab`, and enough device and network configuration to come up cleanly.

Version notes:

1. `1.1.1` and `1.1.2` are nearly the same. `pkgtool` is unchanged, and the `setup` differences are minor fixes and package-list updates rather than a different installer flow.
2. `2.0.0` through `2.2` keep the same overall structure without a separate kernel-install helper. Kernel and boot handling stay inside `setup.tty`.
3. `2.3` adds more explicit Slackware CD-ROM handling and preserves the `/cdrom` mount information in the installed system.
4. `3.0` keeps the same overall flow as `2.3`; the main differences are media naming and package-set naming, not installer structure.
5. `3.1` and `3.9` add `addkerne.tty`, which breaks the kernel-copy step out of `setup.tty`. That helper can install a kernel from the boot disk, a DOS floppy, or the Slackware CD-ROM and then set the root device with `rdev`.
6. `3.1` and later also call packaged setup helpers from `/var/adm/setup` during the post-install phase, so more of the machine-specific configuration can be delegated to scripts shipped in the package set.

This is the family handled by `pkginst/111.sh`, `pkginst/112+.sh`, and `pkginst/shared.sh`.
