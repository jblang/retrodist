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

- Some installers mount the staged install disk as plain `msdos`, so filenames
  and paths need to remain DOS-friendly.

## `debian.sh`

### Purpose

`debian.sh` contains Debian base-install helpers and early `.deb` package
install helpers. The public wrappers in `common.sh` are:

- `debian_install_base`
  Sources `debian.sh` and calls `_debian_install_base`.

- `debian_install_packages_flat`
  Sources `debian.sh` and calls `_debian_install_packages_flat`.

The script also defines `debian_install_packages_tree`, which installs every
`.deb` under the staged installer mount. It is not currently wrapped by
`common.sh`.

### Version Status

- `0.91`: Working `autoinst` and `autoconf`.
- `0.93R6`: Not supported because the installer kernel does not support MSDOS filesystems.
- `1.1`, `1.2`, `1.3`: Working `autoinst`. `autoconf` is not implemented yet.

### Base Install Flow

For `DEBIAN_BASE_STYLE=dinstall`, `_debian_install_base`:

1. Resets `PATH` to the Debian installer paths.
2. Extracts the base system from `DEBIAN_BASE_TARBALL` or from
   `DEBIAN_BASE_DISKS`.
3. Moves `fstab.tmp` into the target `/etc/fstab`.
4. Runs `DEBIAN_PREPARE_FUNCTION` when set.
5. Installs the boot kernel from `bootflop/install.sh` or from the boot floppy
   when `DEBIAN_INSTALL_BOOT_FLOPPY` is set.
6. Installs driver modules from `drivers/install.sh` when
   `DEBIAN_INSTALL_DRIVERS` is set.
7. Seeds NE2000 module configuration when `DEBIAN_CONFIGURE_MODULES` is set.
8. Copies first-boot setup hooks into the target.
9. Writes and installs a target LILO configuration.

For `DEBIAN_BASE_STYLE=091`, `_debian_install_base` uses the older Debian 0.91
path. That path extracts `basedsk1.img` and `basedsk2.img` with `zcat | cpio`,
rewrites root-device references in the installed rc scripts and `lilo.conf`,
runs `rdev`, installs LILO, and copies `autoconf.sh` to `/sbin/setup.sh` in the
target.

### Package Install Flow

`_debian_install_packages_flat` installs `.deb` files from
`$INSTMOUNT/packages`. `debian_install_packages_tree` installs `.deb` files
found anywhere under `$INSTMOUNT`.

Both package helpers unpack packages directly with `zcat | cpio`, run
`fixperms` when package permission metadata is present, run non-interactive
`.inst` scripts from `/var/adm/dpkg/inst`, and remove each `.inst` script after
handling it.

### Variables

Defaults for `DEBIAN_BASE_STYLE=dinstall` are:

- `DEBIAN_PREPARE_FUNCTION=prepare_base_system_dinstall`
- `DEBIAN_ROOT_HOOK=.configure`
- `DEBIAN_INSTALL_BOOT_FLOPPY=1`
- `DEBIAN_CONFIGURE_MODULES=1`
- `DEBIAN_GUARD_ETH0=1`

Common manifest variables:

- `DEBIAN_BASE_STYLE`
  Base install flow selector. Defaults to `dinstall`; set to `091` for Debian
  0.91.

- `DEBIAN_BASE_TARBALL`
  Name of the `base*.tgz` archive on the staged install disk.

- `DEBIAN_BASE_DISKS`
  Space-separated list of base disk names used when `DEBIAN_BASE_TARBALL` is
  not set. The `091` style defaults this to
  `basedsk1 basedsk2 basedsk3`, although the current 0.91 extraction path reads
  `basedsk1.img` and `basedsk2.img` directly.

- `DEBIAN_PREPARE_FUNCTION`
  Optional helper to run after extracting the base system and before later
  install steps.

- `DEBIAN_INITTAB_FALLBACK`
  Alternate location for the shipped `inittab` on releases where the package
  layout is odd.

- `DEBIAN_ROOT_HOOK`
  Name of the file created in `/root/` to continue configuration on first boot.

- `DEBIAN_ROOT_TARBALL`
  Optional tarball on the installer media to unpack into `/target/root` instead
  of copying `/etc/root.sh` directly.

- `DEBIAN_TAR_EXTRACTOR`
  Optional tar extractor override. `bo` uses `star -x`.

- `DEBIAN_INSTALL_BOOT_FLOPPY`
  When set, run the release's `install.sh` from the staged boot floppy tree or
  from `/dev/fd0` to install the kernel.

- `DEBIAN_INSTALL_DRIVERS`
  When set, install modules from a staged `drivers/` tree.

- `DEBIAN_CONFIGURE_MODULES`
  When set, seed `/etc/modules` and `/etc/conf.modules` for the QEMU NE2000 ISA
  NIC and preserve `modules.old` to match the installer's progress checks.

- `DEBIAN_GUARD_ETH0`
  Set by this helper for `dinstall` releases and consumed by the networking
  configuration helper to avoid bringing up missing `eth0` devices.

- `DEBIAN_OPTIONAL_LILO`
  Skip the LILO step if the expected target binaries are not present.

- `DEBIAN_SKIP_SETUP_SH`
  Skip copying `/etc/setup.sh` for releases that use a different handoff
  mechanism.

### Version Notes

- Debian 0.91 is the only Debian target in the repo that currently has both
  working `autoinst` and `autoconf`.

- Debian 0.93R6 has a `prepare_base_system_093r6` helper for its alternate
  `inittab` layout, but the automated path is blocked by the installer kernel's
  staged-disk support.

- Buzz, Rex, and Bo are currently the working Debian 1.x `autoinst` targets.

- `bo` is close to Rex structurally, but uses `root.sh.tar.gz` for the root
  handoff and needs `star -x` rather than the plain `star` invocation that works
  for Buzz and Rex.

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

1. Normalizes `SETS` so spaces, semicolons, and commas become the `pkgtool`
   `#` separator.
2. Locates a staged `slakware/` or `slackware/` package tree under
   `$INSTMOUNT`; if none exists, mounts `CD_DEVICE` on `CD_MOUNT` and searches
   there.
3. Selects the best available `pkgtool` binary from the installer environment.
4. Uses staged `tagfiles/` when present. Otherwise it uses the `.new` tagfile
   extension mode expected by generated tagfiles.
5. Runs `pkgtool` with `-source_mounted`, `-source_dir`, `-target_dir`, and
   `-sets`.
6. Writes the root device, installs `fstab`, adds `/proc`, and preserves a
   `/cdrom` entry when a CD-ROM source was mounted.
7. Creates `/dev/cdrom` when `CD_DEVICE` is set.
8. Fixes selected target permissions and compatibility symlinks.
9. Sets the timezone when `TIMEZONE` is set and zoneinfo is available.
10. Writes and installs LILO when a target LILO binary is available.
11. Installs the first-boot `autoconf.sh` hook through `/etc/rc.d/rc.local`.

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
5. Moves `fstab.tmp` into the target `/etc/fstab`.
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
