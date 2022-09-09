# Retro Distro Playground

This repo contains tools for exploring early Linux distributions in [QEMU](https://www.qemu.org/), a cross-platform emulation and virtualization tool. If you don't already have QEMU, [download it](https://www.qemu.org/download/) or install it using your distro's package manager.

Running retro distros in QEMU has been done many times by many people, but until now there has not been a central repository of recipes for running a wide variety of distros.

## Retro Distros

Scripts are provided for downloading, extracting, and running retro distros. All of the scripts take a configuration directory as their first argument. 

- `qemu.sh` will start the specified distro using the disk images in the `.retro/qemu` directory. Any additional arguments are passed to QEMU verbatim. 
- `extract.sh` will extract the specified distro into the `.retro/cache` directory.
- `download.sh` will download the specified distro's original files into the `.retro/orig` directory.

You won't normally need to run `extract.sh` and `download.sh` manually.  If the distro's cache directory doesn't exist, `qemu.sh` will automatically run each of them in turn.

The configuration directories are organized into a `distro/version/variant` heirarchy within the [distro](distro) directory.  In addition to the configuration files, distro directories may contain a README with pertinent information.

Old distros don't support power management, so you should manually run `shutdown -h now` before closing QEMU. To exit QEMU from the command line type `ctrl-a`, then `x` (not `ctrl-x`).

## CD-ROMs

Throughout the 90s, companies sold CD-ROMs with distros on them, usually for less than $50.  Oftentimes these discs also included snapshots of popular Linux FTP sites such as `sunsite.unc.edu` and `tsx-11.mit.edu`. These CD-ROMs were a valuable service in the age of dialup internet, and today they are valuable time capsules that capture the state of the Linux world at the time they were pressed.

Configuration files are provided in the [cdrom](cdrom) directory for downloading and extracting CD ISOs.

## Jump Box

Old distributions are riddled with security holes and have no business being on the internet. If you were to connect them, they often do not support modern network protocols, so you can't do much.  Yes, you *can* put Slackware 1.0 on the internet and `ping www.google.com`, but that's about it, and that's probably a good thing. Even its FTP client won't work from behind a firewall because it doesn't support passive mode.

As a solution, the `jump.sh` script will start a modern Ubuntu image configured as a jump box with an FTP server and other niceties to interact with your retro boxes. This box has a connection to the internet but also a second private network interface that all the retro boxes can talk to.

The jump box must be started before any retro distros in order for networking to work properly. It is accessible to the retro distros via IP `10.0.2.1` The username and password is `retro`/`retro`.  

The VM's SSH port is forwarded to `2222` on the host, so you can ssh, scp, or sftp into it from the host. Examples:

````
ssh -i .retro/jump/id_rsa -p 2222 retro@localhost
sftp -i .retro/jump/id_rsa -P 2222 retro@localhost
scp -i .retro/jump/id_rsa -P 2222 files retro@localhost:
scp -i .retro/jump/id_rsa -P 2222 retro@localhost:files .
````

Infuriatingly, ssh uses lowercase `-p` to specify the port, while scp and sftp use uppercase `-P`, so if your command doesn't work, make sure you're using the proper case.

## Adding Distros

To add support for a new distro, create a new configuration directory.  Configuration files should address the following steps.

### Downloading

Downloads are configured using one of the following files, in order of precedence:

- `download.sh`, if present, will be executed to download the files. This provides a general mechanism to handle special cases.
- `urls.txt`, if present, contains a list of files to download in the format `filename url` with one file per line.
- `slackver.txt`, if present, contains the version of Slackware to download from the Slackware's [official mirror](https://mirrors.slackware.com/slackware/).

### Extraction

If an `extract.sh` file exists in the distro's directory, the main `extract.sh` script will call it to perform distro-specific extraction. Otherwise, it will attempt to extract any zips, tar.gz archives, and ISO files that were downloaded into the distro's cache directory.

### Preparation

The `qemu.sh` script will source `prep.sh` from the distro directory if it exists. This script should do the following:
- Override any non-default values for the `QEMU_*` variables from `qemu.sh`.
- Create disk images or directories necessary for installation. 

Files in the distro's directory will be attached as follows:
- `fda.img` and `fdb.img` will be attached to the first and second floppy drives, respectively.
- The following images or directories will be attached to the corresponding IDE device, in order of precedence:
  - `hda.img` through `hdd.img`: the format is assumed to be qcow2.
  - `hda.iso` through `hdd.iso`: the format is assumed to be raw, and will be treated as a CD-ROM.
  - Directories `hda` through `hdd`: the files in the directory can be mounted as a FAT filesystem in the VM via `/dev/hdb1`, etc.

## Credits

- [QEMU Advent Calendar](https://www.qemu-advent-calendar.org/2014/) for giving me the idea to start playing with this.  Slackware 1.0 is Day 1 from 2014.
- [Archive.org](https://archive.org/) for keeping around all the old CD-ROM and floppy images of distros gone by.
- [Joshua Powers](https://powersj.io/posts/ubuntu-qemu-cli/) for instructions on running an Ubuntu cloud image in QEMU.

## License

The scripts in this repo are under MIT license.

Copyright 2022 J.B. Langston

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.