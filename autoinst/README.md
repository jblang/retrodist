# Autoinstall Scripts

This directory contains scripts that automate installation and configuration of various distros.

## Directory Layout

- `autoinst.sh`: main installation script
- `autoconf.sh`: main configuration script
- `common`: scripts that can be used for multiple distros
- `distro`: scripts specific to a particular distro (e.g., `slackware`)
- `common/diskinit.sh`: shared disk layout constants and fdisk command generation

## Preparation

If a distro supports automated installation and/or configuration, it should:

- Call the `autoinst_prep` function from its `extract.sh` script to copy the appropriate scripts to the distro's installation media.

- Supply an `autoinst.sh` manifest which sets install-time variables and calls the install helper functions in the correct order.

- Supply an `autoconf.sh` manifest which sets post-install variables and calls the configuration helper functions in the correct order.

- Keep helper logic under `autoinst/common`, `autoinst/debian`, or `autoinst/slakware` as function-only scripts so the main runners can source them up front.

## Notes

- Install scripts will run from the installation root floppy so the commands available are very limited. `sed` and `cut` are typically available, but other commands such as `grep`, `awk`, etc. are missing.  `sed` can be used to simulate many grep commands.

- Config scripts run after the base system has been installed so most commands should be available, but they are old versions and likely to be missing some new features.

- Some distro directories have their own README files with additional implementation notes. For Debian-specific script layout and generation notes, see [debian/README.md](/Users/jblang/repos/retrodist/autoinst/debian/README.md).

- The main runners source the helper trees from `autoinst.d`, then source `autoinst.d/config/autoinst.sh` or `autoinst.d/config/autoconf.sh` to set variables and call the desired helper functions.

- Helper trees such as `common/`, `debian/`, and `slakware/` are copied recursively into `autoinst.d` rather than symlinked. This matters for old installers that see the staged disk through a DOS-backed filesystem export.

- Some older installers mount the staged disk as plain `msdos`, so helper filenames and directory layout need to remain DOS-friendly.
