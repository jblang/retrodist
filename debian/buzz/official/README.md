# Debian 1.1 (Buzz)

Debian 1.1, codenamed Buzz, was released in June 1996. In this repo, `autoinst` is fully working and tested for the base installation path, including partitioning, base system installation, kernel and module setup, networking, and bootloader installation.

### Automatic Installation

To automatically install Debian Buzz, ignore the onscreen instructions and enter the following instead:

```sh
mount -t msdos /dev/hdb1 /mnt
/mnt/autoinst.d/autoinst.sh
```

- The script will automatically partition and format the hard drive, install the base system, install the boot kernel and modules, configure networking, and install LILO.
- After the VM reboots, the installed system should boot from the hard drive with networking working under the default QEMU NE2000 ISA NIC.
- `autoconf` is not implemented yet for this release, so the post-boot package/configuration phase still has to be done manually if you want a more complete system.

### Manual Installation

The original installer still works if you want the authentic install flow.

- Follow the normal Buzz installer steps from the rescue/root environment.
- Refer to [config.sh](config.sh) for the network and serial settings used by the automated configuration.
