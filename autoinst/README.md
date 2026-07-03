# Autoinstall Scripts

This directory contains the shared runtime copied onto staged installer media
for automated distro installation and first-boot configuration.

`retrolib/extract.sh` stages this tree during `retro extract` with
`autoinst_prep`: it copies the main install runner to `qemu.d/fat/autoinst`,
copies this directory to `qemu.d/fat/autoinst.d`, and copies any configured
distro manifests to `qemu.d/fat/autoinst.d/distro/`.

For the host-side staging process and config file lookup rules, see
[retrolib/README.md](../retrolib/README.md). For adding a new distro manifest,
see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Reference vs. Staged Files

Do not edit `qemu.d/fat/autoinst.d/` files directly. They are generated copies
staged for automated installs and will be overwritten.

Edit the source files instead:

- Shared runtime and helper scripts live in this `autoinst/` directory.
- Debian per-version install manifests live under `debian/VERSION/`.
- Slackware per-version or per-variant manifests live under `slackware/`.
- Other distro manifests live beside their distro config.

## Compatibility Notes

- These scripts run in very old installer and target-system environments. Keep
  shell code portable and avoid modern shell features.

- Never use command status negation such as `if ! command; then`.
  - Some old versions of bash treat `!` as a command and print `!: not found`. 
  - This causes old ash versions run the right-hand function in a subshell,
    so any variables set inside the function are discarded when the subshell exits.
  - Negation inside `test` such as `[ ! -f file ]` is fine.

- Install scripts run from the installer media with a limited command set. `sed`
  and `cut` are usually available; tools such as `grep`, `awk`, `which`, and
  `command -v` may be missing.

- Configuration scripts run after the base system has been installed, so more
  commands are usually available, but they are old versions and may lack modern
  options.

- Some installers mount the staged disk as plain `msdos`, so helper filenames
  and directory layout need to remain DOS-friendly.

## `autoinst.sh`

`autoinst.sh` is the install-time runner. It is copied to the staged installer
FAT directory as `autoinst`.

At runtime it:

1. Extends `PATH` with common installer binary locations.
2. Derives `INSTMOUNT` from the runner's own path so the staged media can be
   mounted anywhere.
3. Selects `ROOTMOUNT` from known historical installer layouts:
   `/target`, `/var/adm/mount` with `/mnt`, or `/root`.
4. Verifies that `autoinst.d` exists under the staged media.
5. Sources `autoinst.d/common.sh`.
6. Initializes logging with `AUTOINST_DEBUG=0` unless overridden and
   `AUTOINST_LOG=${TMPDIR:-/tmp}/autoinst.log` unless overridden.
7. Sources `autoinst.d/distro/autoinst.sh`.
8. Copies the install log to `$ROOTMOUNT/autoinst.log`.
9. Prompts for ENTER, syncs, and reboots.

The distro `autoinst.sh` manifest is responsible for setting install-time
variables and calling wrapper functions such as `disk_init`,
`debian_install_base`, `slackware_pkgtool_install`, or `sls_sysinstall`.

## `autoconf.sh`

`autoconf.sh` is the first-boot configuration runner. Distro install paths that
need a post-install configuration pass copy it into the target system and
arrange for it to run on boot.

At runtime it:

1. Extends `PATH` with common installed-system binary locations.
2. Mounts the staged install disk from `/dev/hdb1` at `/retro`.
3. Verifies that `/retro/autoinst.d` exists.
4. Sources `/retro/autoinst.d/common.sh`.
5. Initializes logging with `AUTOINST_DEBUG=0` unless overridden and
   `AUTOINST_LOG=/autoinst.log` unless overridden.
6. Sources `/retro/autoinst.d/distro/autoconf.sh`.
7. Removes the running script so it does not run again.
8. Syncs and reboots unless `AUTOCONF_REBOOT` is `0`, `false`, or `no`.

The distro `autoconf.sh` manifest is responsible for setting configuration
variables and calling wrappers such as `mod_config`, `net_config`,
`mail_config`, and `x11_config`.

## `common.sh`

`common.sh` is sourced by both main runners. It sources `logging.sh` and
`diskutil.sh`, then defines public wrapper functions that load the
implementation scripts on demand.

Install wrappers are documented in [install/README.md](install/README.md).
First-boot configuration wrappers are documented in
[config/README.md](config/README.md).

## `logging.sh`

`logging.sh` provides portable echo-based logging helpers. Messages are written
to stderr with bright ANSI-colored prefixes, and are appended without color to
`$AUTOINST_LOG` when that variable is set.

Logging helpers:

- `log_debug`
  Logs a `DEBUG:` message only when `AUTOINST_DEBUG=1`.

- `log_info`
  Logs an `INFO:` message.

- `log_warn`
  Logs a `WARN:` message.

- `log_error`
  Logs an `ERROR:` message.

- `log_attention`
  Logs an `ATTN:` message for interactive prompts or important operator
  attention.

- `log_div`
  Logs an 80-column divider line.

- `die`
  Logs an `ERROR:` message and exits 1. Use for critical steps whose failure
  would leave a broken or partial guest.

## `diskutil.sh`

`diskutil.sh` contains shared disk preparation helpers and is loaded by
`common.sh`.

When `disk_init` is called without partition geometry arguments, it detects the
target disk geometry from the interactive `p`/`q` fdisk listing for `DISKDEV`.

Manifests may still pass explicit geometry as
`swapstart swapend rootstart rootend` when needed.

It also provides:

- `disk_init`
  Detects or creates the default swap/root partition layout, formats swap,
  formats and mounts the root filesystem, and creates `fstab.tmp`. Four
  optional arguments may be provided as `swapstart swapend rootstart rootend`;
  otherwise fdisk geometry is autodetected.

- `make_boot_floppy`
  Writes the installed kernel to a boot floppy and sets its root device.

## `fdisk/`

`fdisk/geometry.sh` and `fdisk/swaproot.sh` are small guest-side helpers used
by host-driven install scripts. `geometry.sh DEVICE` prints the interactive
fdisk geometry listing for the target disk. `retrolib/script.sh` parses that
screen output and calculates the partition split on the host, then calls
`swaproot.sh DEVICE swapstart swapend rootstart rootend` in the guest to write
the partition table.

Common disk variables:

- `DISKDEV`
  Target disk. Defaults to `/dev/hda`.

- `SWAPPART`
  Swap partition number. Defaults to `1`.

- `ROOTPART`
  Root partition number. Defaults to `2`.

- `SWAPDEV`
  Swap device. Defaults to `$DISKDEV$SWAPPART`.

- `ROOTDEV`
  Root device. Defaults to `$DISKDEV$ROOTPART`.

- `ROOTFS`
  Root filesystem type. Defaults to `ext2`; `ext` is also supported.

- `FDISK_REBOOT`
  When set, `disk_init` exits after writing a new partition table so the VM can
  be rebooted before formatting.

- `DISK_SWAP_MB`
  Swap size used when autodetecting partition geometry. Defaults to `128`.
  Common QEMU CHS layouts are supported without relying on shell arithmetic.

- `FDISK_SWAP_CYLINDERS`
  Swap cylinder count used when autodetecting partition geometry. Overrides
  `DISK_SWAP_MB`.

- `BOOTFLOPPYDEV`
  Boot floppy device for `make_boot_floppy`. Defaults to `/dev/fd0`.

- `BOOTKERNEL`
  Kernel image for `make_boot_floppy`. Defaults to `$ROOTMOUNT/Image`.

## `install/`

`install/` contains distro-specific install helpers loaded through `common.sh`.
See [install/README.md](install/README.md) for details.

## `config/`

`config/` contains first-boot configuration helpers loaded through `common.sh`.
See [config/README.md](config/README.md) for details.

## Distro Manifests

Each supported distro directory can provide:

- `autoinst.sh`
  Install-time manifest copied to `autoinst.d/distro/autoinst.sh`.

- `autoconf.sh`
  First-boot configuration manifest copied to
  `autoinst.d/distro/autoconf.sh`.

The manifests should set only the variables needed by that distro and call the
public wrappers from `common.sh`. Helper implementation code should stay in this
directory as function-only scripts so it can be sourced safely by the runners.
