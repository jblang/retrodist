# Debian 1.3 (Bo)

Debian 1.3, codenamed Bo, was released in July 1997. In this repo, `autoinst` is fully working and tested for the base installation path through the same shared Debian 1.x installer framework used for Buzz and Rex.

### Automatic Installation

To automatically install Debian Bo, ignore the onscreen instructions and enter the following instead:

```sh
mount -t msdos /dev/hdb1 /mnt
/mnt/autoinst
```

- The script will automatically partition and format the hard drive, install the base system, install the boot kernel and driver modules, configure networking, and install LILO.
- This release uses the same automated base-install path as the other Debian 1.x entries in the repo, with Bo-specific handling for its rescue environment and root hook tarball.
- `autoconf` is not implemented yet for this release, so only the base installation is automated at present.

### Manual Installation

The original Bo installer can still be used if you want to go through the historical install flow.

- Follow the onscreen installer steps from the rescue/root environment.
- Refer to [config.sh](config.sh) for the network and serial settings used by the automated configuration.
