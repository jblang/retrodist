# Debian 0.93R6

Debian 0.93R6, released in late 1995, was the last Debian 0.x release before the Debian 1.x series. In this repo it has configuration files for the automatic install path, but that path is not currently usable because the installer kernel does not support mounting the staged MSDOS install disk.

### Automatic Installation

Automatic installation is currently untested and expected not to work end-to-end.

- The repo includes `autoinst` support for the release layout.
- The blocker is kernel support for the MSDOS filesystem used to expose `/dev/hdb1`.
- `autoconf` is not currently available for this release.

### Manual Installation

Use the original installer flow for now.

- Boot the installer and follow the onscreen steps to partition the disk, initialize swap, format the root partition, and install the base system.
- When the installer asks for the additional base floppies, use the QEMU monitor to swap in the extracted images from `.extract/`.
- Complete the remaining installer steps manually.

Refer to [config.sh](config.sh) for the network and serial settings used by the automated configs.
