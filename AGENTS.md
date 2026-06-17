# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## What This Is

Retro Distro Playground automates downloading, extracting, and installing early Linux distributions (SLS, Slackware 1.0–9.0, Debian 0.91–1.3, RedHat 1.1–3.0.3) inside QEMU, with fully scripted unattended installs.

## Entry Point Commands

```bash
retro prereq                        # install host dependencies (qemu, 7z, wget, lsof, jq, etc.)
retro boot slackware/3.0/walnut     # download + extract + boot a distro
retro install slackware/3.0/walnut  # boot from install media with scripted install
retro extract slackware/3.0/walnut  # download + stage files into qemu.d/
retro download slackware/3.0/walnut # download source files only
retro reset slackware/3.0/walnut    # delete qemu.d/ and extracted files
retro package slackware/3.0/walnut  # build a tar with qemu.d/ + runnable scripts

jump run      # start a modern Debian jump box (for FTP file transfer to retro VMs)
jump ssh      # SSH into jump box (user/pass: retro/retro)
jump sftp     # SFTP into jump box
jump scp      # SCP file into jump box

qmp dump-screen          # dump VGA text memory from running VM
qmp send-text -n 'text'  # type text + Enter into VM
qmp send-key ret         # send a single key
qmp change-image root.img
qmp eject-disk
```

Extra arguments after the config path are passed to QEMU verbatim.

## Architecture

### Top-Level Scripts

- `retro` — main entry point; sources all `retrolib/*.sh` libraries, parses `COMMAND` + `CONFIG`, dispatches
- `jump` — starts/connects to a modern Debian VM acting as a network bridge for FTP
- `qmp` — CLI wrapper around `retrolib/qmp.sh` functions

### `retrolib/` — Host-Side Library

All modules are sourced into `retro` at startup. See [retrolib/README.md](retrolib/README.md) for per-file function references, `EXTRACT_*` and `QEMU_*` variable documentation, QEMU hardware profiles, and network modes.  Read compatibility notes section of this file before touching any files in the `retrolib` directory.

### Config Directory Hierarchy and `qemu.d/`

See [retrolib/README.md](retrolib/README.md) for the per-config file table and the `qemu.d/` staging area layout.

### `autoinst/` — In-Guest Runtime

These scripts run **inside old Linux installer environments**. See [autoinst/README.md](autoinst/README.md) for file-by-file documentation and portability constraints before touching anything here.

## Adding a New Distro

1. Create `distro/version/variant/` directory.
2. Add a download config (`download.txt`, `slackmirror.txt`, `debmirror.txt`, or `download.sh`).
3. Write `extract.sh` — set `EXTRACT_*` variables and call `extract_install_files`.
4. Write `qemu.sh` — set `QEMU_PROFILE` and any hardware overrides.
5. Write `script.sh` — sequence of `script_*` calls to drive the installer via QMP.
6. Write `autoinst.sh` — set disk/package variables and call appropriate `common.sh` wrappers.
7. Optionally write `autoconf.sh` for first-boot configuration. Load kernel
   modules with `MOD_ENABLE` + `mod_config`, and configure networking with
   `net_config` (these are now separate steps).

Look at `slackware/3.0/walnut/` for a minimal working example.

## Critical: Reference vs. Staged Files

**DO NOT edit `qemu.d/fat/autoinst.d/` files directly.** These are staged copies created during `retro extract`.

**Always edit the source files:**
- `autoinst/` — top-level reference scripts (install/debian.sh, common.sh, config/*.sh, etc.)
- `debian/VERSION/autoinst.sh` — per-version distro installer reference
- `slackware/VERSION/VARIANT/autoinst.sh` — per-variant distro installer reference

The staged `qemu.d/` copies inside distro directories are **generated/copied from the top-level references** during the extract phase. Edits to `qemu.d/fat/autoinst.d/` will be lost or overwritten.

Example: editing `debian/1.1/infomagic/qemu.d/fat/autoinst.d/install/debian.sh` is wrong. Edit `autoinst/install/debian.sh` instead, and the change propagates to all distros.
