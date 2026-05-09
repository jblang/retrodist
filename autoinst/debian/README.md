# Debian Autoinstall Scripts

This directory contains the Debian-specific install and configuration helpers used by `autoinst.sh`.

## Layout

- `baseinst.sh`
  Combined base-install helper containing the Debian 0.91 path and the shared Debian 0.93R6 / 1.x flow behind one `debian_install_base` entrypoint.

- `dpkginst.sh`
  Combined post-install package installation helper for both flat-package and package-tree layouts.

## Tested Status

- `0.91`
  Working `autoinst` and `autoconf`.

- `0.93R6`
  Script layout is present, but the automated path is not currently usable because the installer kernel does not support the staged MSDOS install disk.

- `buzz`
- `rex`
- `bo`
  Working `autoinst`. `autoconf` is not implemented yet.

## Debian 1.x Flow

For Debian targets, the distro `autoinst.sh` manifest sets release-specific variables directly and then calls the shared `debian_install_base` function.

That shared flow runs the steps in order:

1. Extract the base system.
2. Prepare `inittab` / `unconfigured.sh` state if needed.
3. Install the boot kernel from the rescue or boot floppy.
4. Install driver modules when the release has a separate driver disk.
5. Seed module configuration for the default QEMU NE2000 ISA NIC.
6. Copy the root/setup handoff scripts used by the historical installer.
7. Install LILO and activate the boot partition.

## Base Variables

The Debian manifests customize the shared flow through shell variables before they call `debian_install_base`.

Defaults for `DEBIAN_BASE_STYLE=dinstall` are:

- `DEBIAN_PREPARE_FUNCTION=prepare_base_system_dinstall`
- `DEBIAN_ROOT_HOOK=.configure`
- `DEBIAN_INSTALL_BOOT_FLOPPY=1`
- `DEBIAN_CONFIGURE_MODULES=1`
- `DEBIAN_GUARD_ETH0=1`

Common ones are:

- `DEBIAN_BASE_TARBALL`
  Name of the `base*.tgz` archive on the staged install disk.

- `DEBIAN_BASE_STYLE`
  Base install flow selector. Defaults to `dinstall`; set to `091` for Debian 0.91.

- `DEBIAN_PREPARE_FUNCTION`
  Optional helper to run after extracting the base system and before later install steps. Defaults to `prepare_base_system_dinstall` for `dinstall` releases.

- `DEBIAN_INITTAB_FALLBACK`
  Alternate location for the shipped `inittab` on releases where the package layout is odd.

- `DEBIAN_ROOT_HOOK`
  Name of the file created in `/root/` to continue configuration on first boot. Defaults to `.configure` for `dinstall` releases.

- `DEBIAN_ROOT_TARBALL`
  Optional tarball on the installer media that should be unpacked into `/target/root` instead of copying `/etc/root.sh` directly.

- `DEBIAN_TAR_EXTRACTOR`
  Optional extractor override for environments where plain `star` is not the right invocation. `bo` uses `star -x`.

- `DEBIAN_INSTALL_BOOT_FLOPPY`
  When set, run the release's `install.sh` from the boot or rescue floppy to install the kernel. Enabled by default for `dinstall` releases.

- `DEBIAN_INSTALL_DRIVERS`
  When set, install modules from a separate staged `drivers/` tree.

- `DEBIAN_CONFIGURE_MODULES`
  When set, seed `/etc/modules` and `/etc/conf.modules` for the QEMU NE2000 ISA NIC and preserve `modules.old` to match the installer's progress checks. Enabled by default for `dinstall` releases.

- `DEBIAN_GUARD_ETH0`
  When set, only bring up `eth0` if the interface actually exists at boot. Enabled by default for `dinstall` releases.

- `DEBIAN_OPTIONAL_LILO`
  Skip the LILO step if the expected target binaries are not present.

- `DEBIAN_SKIP_SETUP_SH`
  Skip copying `/etc/setup.sh` for releases that use a different handoff mechanism.

## Compatibility Notes

- These scripts run inside very old installer environments. Avoid modern shell features and do not assume common helpers like `which` or `command -v` work.

- The staged install disk is mounted as `msdos`, so long filenames can be constrained by DOS 8.3 behavior. The Debian helper layout uses subdirectories such as `baseinst/` and `dpkginst/` to keep the staged names readable while avoiding collisions.

- Debian 0.91 still uses a separate internal code path selected with `DEBIAN_BASE_STYLE=091`. The extraction method, installed layout adjustments, and follow-on package handling are older and do not fit the shared `dinstall` runner cleanly.

- `bo` is close to Rex structurally, but not identical. It uses `root.sh.tar.gz` for the root handoff and needs `star -x` rather than the plain `star` invocation that worked for Buzz and Rex.

- Buzz, Rex, and Bo are currently the working Debian 1.x `autoinst` targets.

- Debian 0.91 is the only Debian target in the repo that currently has both working `autoinst` and `autoconf`.
