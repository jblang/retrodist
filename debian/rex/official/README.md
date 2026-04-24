# Debian 1.2 (Rex)

Debian 1.2, codenamed Rex, was released in December 1996. In this repo, `autoinst` is fully working and tested through the base system install, boot kernel and driver-module install, network configuration, and hard-disk boot setup.

### Automatic Installation

To automatically install Debian Rex, ignore the onscreen instructions and enter the following instead:

```sh
mount -t msdos /dev/hdb1 /mnt
/mnt/autoinst
```

- The script will automatically partition and format the hard drive, install the base system, install the kernel and driver modules, seed module configuration for the default QEMU NE2000 ISA NIC, configure networking, and install LILO.
- After the VM reboots, the installed system should boot successfully from the hard drive with Ethernet working.
- `autoconf` is not implemented yet for this release, so only the base installation is fully automated right now.

### Manual Installation

The original Rex installer can still be used if you want the historical flow.

- Follow the onscreen installer steps from the rescue/root environment.
- Refer to [config.sh](config.sh) for the network and serial settings used by the automated configuration.
