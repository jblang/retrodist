# Autoinstall Scripts

This directory contains scripts that automate installation and configuration of various distros.

## Directory Layout

- `autoinst.sh`: main installation script
- `autoconf.sh`: main configuration script
- `common`: scripts that can be used for multiple distros
- `distro`: scripts specific to a particular distro (e.g., `slackware`)
- `fdisk`: partition tables that get translated to fdisk commands for disks of various sizes

## Preparation

If a distro supports automated installation and/or configuration, it should:

- Call the `autoinst_prep` function from its `extract.sh` script to copy the appropriate scripts to the distro's installation media.

- Supply an `autoinst.txt` file listing which scripts to run during installation and in what order.

- Supply an `autoconf.txt` file listing which scripts to run during post-install configuration and in what order.

- Supply a `config.sh` script which sets up environment variables that are used by various installation and configuration steps.  

## Notes

- Install scripts will run from the installation root floppy so the commands available are very limited. `sed` and `cut` are typically available, but other commands such as `grep`, `awk`, etc. are missing.  `sed` can be used to simulate many grep commands.

- Config scripts run after the base system has been installed so most commands should be available, but they are old versions and likely to be missing some new features.

- The `config.sh` script and all the scripts specified by `autoinst.txt ` and `autoconf.txt` are copied to the installation media and sourced by the main script prior to running the individual steps.

- When the files specified in `autoinst.txt` and `autoconf.txt` are copied to the installation media they are renamed to numbered files in the `inststep` and `confstep` directories so that they are executed in the correct order.