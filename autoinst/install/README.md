# Autoinstall Install Helpers

This directory contains distro-specific installation helpers used by
`autoinst.sh`. These scripts are copied into the staged installer media under
`autoinst.d/install/`.

The public helper functions are defined in `autoinst.d/common.sh`. Those
wrappers source the scripts in this directory and call the underscored
implementation functions here.

## Compatibility Notes

- These scripts run inside very old installer environments. Avoid modern shell
  features and do not assume helpers such as `which` or `command -v` exist.

- Do not use shell reserved-word negation such as `if ! command; then`.
  Some old Debian installer Bash versions treat `!` as a command and print
  `!: not found`. `test` negation such as `[ ! -f file ]` is fine; use
  explicit status checks instead when negating a command.

- Some installers mount the staged install disk as plain `msdos`, so filenames
  and paths need to remain DOS-friendly.

## `sysinst.sh`

### Purpose

`sysinst.sh` handles early `sysinstall` based SLS and Slackware releases. The
public wrappers in `common.sh` are:

- `slackware_sysinstall`
  Sources `sysinst.sh` and calls `_slackware_sysinstall`.

- `sls_sysinstall`
  Sources `sysinst.sh` and calls `_sls_sysinstall`.

### Slackware Flow

`_slackware_sysinstall` handles Slackware 1.01-style installs:

1. Selects `SYSINSTALL_INSTSRC` or defaults to `$INSTMOUNT/install`.
2. Chooses the install mode from `SYSINSTALL_MODE`, or auto-detects `tex`,
   `X11`, or `mini` from the source tree.
3. Creates the target `install/` bookkeeping directories.
4. Runs `sysinstall -instsrc ... -instroot ... -$INSTTYPE`.
5. Moves `fstab.tmp` into the target `/etc/fstab` when present.
6. Writes `FLOPPYA`, `ROOTDEV`, and `VGAMODE` entries to `/etc/hwconfig`.
7. Runs `etc/syssetup` with canned answers. The `sls103` profile uses a
   slightly different answer sequence.
8. Installs the first-boot `autoconf.sh` hook through `/etc/rc.local`.

### SLS Flow

`_sls_sysinstall` handles SLS package installation:

1. Selects `SLS_INSTALL_MODE`, or auto-detects `all`, `base`, or `mini` from
   the staged source tree.
2. Creates target install bookkeeping directories.
3. Installs any mounted `/user` disk packages.
4. Installs series `a`, then series `b` and `c` for `base` or `all`, then
   series `x` for `all`.
5. Moves `fstab.tmp` into the target `/etc/fstab` when present.

### Variables

- `SYSINSTALL_INSTSRC`
  Optional Slackware `sysinstall` source path. Defaults to `$INSTMOUNT/install`.

- `SYSINSTALL_MODE`
  Optional Slackware install mode. Supported historical modes include `mini`,
  `X11`, `tex`, and `everything`.

- `SYSSETUP_PROFILE`
  Optional profile for `etc/syssetup` answer sequencing. Set to `sls103` for
  the SLS 1.03-style sequence.

- `VGAMODE`
  Optional VGA mode written to `/etc/hwconfig`. Defaults to `-1`.

- `SLS_INSTALL_MODE`
  Optional SLS install mode. Supported values are `mini`, `base`, and `all`.

## `pkgtool.sh`

### Purpose

`pkgtool.sh` handles Slackware `pkgtool` installs. The public wrappers in
`common.sh` are:

- `slackware_pkgtool_install_111`
  Sources `pkgtool.sh` and calls `_slackware_pkgtool_install_111`, which uses
  the Slackware 1.1.1-era `/usr/adm` and `/usr/spool` paths.

- `slackware_pkgtool_install`
  Sources `pkgtool.sh` and calls `_slackware_pkgtool_install`, which uses the
  later `/var/adm` and `/var/spool` paths.

The staged Slackware package tree is named `slakware/` instead of `slackware/`
where needed so the path fits DOS 8.3 filename limits. The helper can still
detect either spelling when reading staged or CD-ROM package sources.

### Install Flow

1. Selects the Slackware layout for the target release:
   `/usr/adm` and `/usr/spool` for the 1.1.1-era wrapper, or `/var/adm` and
   `/var/spool` for later releases.
2. Normalizes `SETS` so spaces, semicolons, and commas become the `pkgtool`
   `#` separator.
3. Locates a staged `slakware/` or `slackware/` package tree under
   `$INSTMOUNT`; if none exists, mounts `CD_DEVICE` on `CD_MOUNT` and searches
   there.
4. Selects the best available `pkgtool` binary from the installer environment.
5. Uses staged `tagfiles/` when present. Otherwise it uses the `.new` tagfile
   extension mode expected by generated tagfiles.
6. Runs `pkgtool` with `-source_mounted`, `-source_dir`, `-target_dir`, and
   `-sets`.
7. Removes temporary setup state, unmounts any CD-ROM source mounted by the
   helper, and exits if `pkgtool` failed.
8. Writes the root device, installs `fstab`, adds `/proc`, and preserves a
   `/cdrom` entry when a CD-ROM source was mounted.
9. Creates a `/dev/cdrom` symlink when `CD_DEVICE` is set.
10. Fixes selected target permissions and compatibility symlinks.
11. Sets the timezone when `TIMEZONE` is set and zoneinfo is available.
12. Writes and installs LILO when a target LILO binary is available.
13. Installs the first-boot `autoconf.sh` hook through `/etc/rc.d/rc.local`.

### Package Skips

Slackware `pkgtool` installs can define per-distribution package skips in
`pkgskip.txt` next to each distro's manifests. During extraction, `retro`
generates tagfiles from the package directories and marks every package listed
in `pkgskip.txt` as `SKP`.

### Variables

- `SETS`
  Package series to install. The helper accepts space-, comma-, or
  semicolon-separated values and converts them for `pkgtool`.

- `ROOTDEV`
  Target root device. Used for `ROOTDEV`, `fstab`, and LILO configuration.

- `TIMEZONE`
  Optional timezone path under `/usr/lib/zoneinfo`.

- `CD_DEVICE`
  Optional CD-ROM block device. Defaults to `/dev/hdc` when no staged package
  tree exists.

- `CD_MOUNT`
  Optional CD-ROM mount point. Defaults to `/var/adm/mount` when no staged
  package tree exists.

### Version Notes

- `1.1.1` and `1.1.2` are nearly the same. `pkgtool` is unchanged, and `setup`
  differences are minor fixes and package-list updates.

- `2.0.0` through `2.2` keep the same overall structure without a separate
  kernel-install helper. Kernel and boot handling stay inside `setup.tty`.

- `2.3` adds more explicit Slackware CD-ROM handling and preserves the `/cdrom`
  mount information in the installed system.

- `3.0` keeps the same overall flow as `2.3`; the main differences are media
  naming and package-set naming.

- `3.1` and `3.9` add `addkerne.tty`, which breaks the kernel-copy step out of
  `setup.tty`. That helper can install a kernel from the boot disk, a DOS
  floppy, or the Slackware CD-ROM and then set the root device with `rdev`.

- `3.1` and later call packaged setup helpers from `/var/adm/setup` during the
  post-install phase, so more machine-specific configuration can be delegated to
  scripts shipped in the package set.

## `deb091.sh`

### Purpose

`deb091.sh` contains Debian 0.91 base-install helpers and early `.deb` package
install helpers. The public wrappers in `common.sh` are:

- `debian_091_install_base`
  Sources `deb091.sh` and calls `_debian_091_install_base`.

- `debian_091_install_packages`
  Sources `deb091.sh` and calls `_debian_091_install_packages`.

### Version Status

- `0.91`: Working `autoinst` and `autoconf`.

### Base Install Flow

`_debian_091_install_base`:

1. Extracts `basedsk1.img` and `basedsk2.img` with `zcat | cpio`.
2. Moves `fstab.tmp` into the target `/etc/fstab`.
3. Rewrites root-device references in `rc.S`, `rc.K`, and `lilo.conf`.
4. Runs `rdev` on the installed kernel.
5. Installs LILO in the target.
6. Copies `autoconf.sh` to `/sbin/setup.sh` in the target.

### Package Install Flow

`_debian_091_install_packages` installs every `.deb` found under `$INSTMOUNT`.
It unpacks packages directly with `zcat | cpio`, runs `fixperms` when package
permission metadata is present, runs non-interactive `.inst` scripts from
`/var/adm/dpkg/inst`, and removes each `.inst` script after handling it.

### Version Notes

- Debian 0.91 is the only Debian target in the repo that currently has both
  working `autoinst` and `autoconf`.

## `debian.sh`

### Purpose

`debian.sh` contains Debian 1.x base-install helpers. The public wrapper in
`common.sh` is:

- `debian_install_base`
  Sources `debian.sh` and calls `_debian_install_base`.

### Version Status

- `1.1`, `1.2`, `1.3`: Working `autoinst`. `autoconf` is not implemented yet.

### Base Install Flow

`_debian_install_base`:

1. Resets `PATH` to the Debian installer paths.
2. Extracts the base system from `DEBIAN_BASE_TARBALL`.
3. Moves `fstab.tmp` into the target `/etc/fstab`.
4. Installs the temporary first-boot `inittab`.
5. Installs the boot kernel from the staged `bootflop/install.sh`.
6. Installs driver modules when staged `drivers/install.sh` exists.
7. Copies first-boot setup hooks into the target, unpacking
   `/etc/root.sh.tar.gz` when present.
8. Writes and installs a target LILO configuration, copies the MBR, and
   activates the target partition.

### Variables

Defaults:

- `DEBIAN_ROOT_HOOK=.bash_profile`

Common manifest variables:

- `DEBIAN_BASE_TARBALL`
  Name of the `base*.tgz` archive on the staged install disk. Required for
  `_debian_install_base`.

- `DEBIAN_ROOT_HOOK`
  Name of the file created in `/root/` to continue configuration on first boot.

### Version Notes

- `1.1`, `1.2`, and `1.3` are currently the working Debian 1.x `autoinst`
  targets.

- `1.3` is close to `1.2` structurally, but uses `root.sh.tar.gz` for the root
  handoff.
