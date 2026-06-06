# Retro Distro Playground

This repo contains tools for exploring early Linux distributions in [QEMU](https://www.qemu.org/), a cross-platform emulation and virtualization tool.

Running retro distros in QEMU has been done many times by many people, but until now there has not been a central repository of recipes for running a wide variety of distros.  This project also emphasizes fully automated installs for reproducible build artifacts.

![chitaotao](screenshots/chitaotao.png)
![x11111](screenshots/x11111.png)


## Prerequisites

You'll need one of these environments set up prior to using Retro Distro Playground:

- On Linux, apt, dnf, and pacman are supported (Arch support is untested btw).
- On macOS, use [Homebrew](https://brew.sh/) to install dependencies.
- On Windows, use [MSYS2](https://www.msys2.org/) to install dependencies. [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) can also be used with the Linux distro of your choice.

Once you have your environment set up, clone the repo from https://github.com/jblang/retrodist.

From the repo root, run this command to install the host prerequisites for your environment:

```
retro prereq
```

This should auto-detect your environment and choose the correct package manager and packages:

- On Linux, `prereq` installs the distribution packages that provide the QEMU
system emulators used by `retro` and `jump`, `qemu-img`, a QEMU window display
backend, `7z`, `unzip`, `wget`, `bchunk`, `xorriso`, `lsof`, and OpenSSH
client tools.
- On macOS with Homebrew, this installs `qemu`, `p7zip`, `unzip`, and `wget`.
Homebrew's `qemu` formula includes both `qemu-system-i386` and `qemu-img`.
- On Windows with MSYS2, `prereq` installs QEMU from the package repo for the active MinGW
environment, plus `p7zip`, `unzip`, `wget`, `xorriso`, `lsof`, and OpenSSH
client tools from the MSYS repo.

The scripts should theoretically be portable to any other Unix-like OS that has the prerequisites installed.

The `package` command (see below) can be used to package the disk images together with a shell script and batch file to start QEMU. This will allow the image to be run on Windows or other operating systems with only QEMU installed. However, the initial preparation needs to be done on a Unix-like system with all the prereqs installed.


## Retro Distros

The `retro` script provides commands for downloading, extracting, and running retro distros. All of the commands take a configuration directory as their first argument. If no directory is provided, the current directory is used.

- `boot` will start the distro using the disk images in the `qemu.d` directory. Any additional arguments are passed to QEMU verbatim.
- `install` will start the distro from install media and run the scripted install if `script.sh` is provided.
- `extract` will extract the distro into the `extract.d` directory.
- `download` will download the distro's original files into the config directory's `download.d` directory.
- `reset` will reset the distro's extracted files and QEMU configuration
- `patch` will patch the distro's boot/root disk for auto-installation (this requires sudo to mount the image)
- `package` will package the disk images and create shell scripts and batch files to run them in QEMU.
- `prereq` will install host prerequisites with the current OS package manager.

You won't normally need to run `extract` and `download` manually since `boot` will automatically run each of them in turn.

The configuration directories are organized into a `distro/version/variant` hierarchy.  In addition to the configuration files, distro directories may contain a README with pertinent information.

Older distros don't support power management, so you should manually run `shutdown -h now` before closing QEMU. To exit QEMU from the command line type `Ctrl-C` at the terminal where you started the `retro` command.  You can also close the display window.


## CD-ROMs

Throughout the 90s, companies sold CD-ROMs with distros on them, usually for less than $50.  Oftentimes these discs also included snapshots of popular Linux FTP sites such as `sunsite.unc.edu` and `tsx-11.mit.edu`. These CD-ROMs were a valuable service in the age of dialup internet, and today they are valuable time capsules that capture the state of the Linux world at the time they were pressed.

Configuration files are provided in the [cdrom](cdrom) directory for downloading and extracting CD ISOs.


## Displays

By default, `retro` starts QEMU with a native window display backend: `gtk` on
Linux and `cocoa` on macOS. Override this by setting `QEMU_DISPLAY`, for example
`QEMU_DISPLAY="-display sdl" retro ... boot`. If QEMU reports that the selected
backend is unavailable, install a QEMU UI backend package such as `qemu-ui-gtk`
or choose another backend supported by `qemu-system-i386 -display help`.


## Network Configuration

By default, `retro` VMs use QEMU's user-mode networking with port forwarding to the host. This provides internet access and convenient SSH/HTTP/Telnet forwarding, but doesn't support guest FTP servers (which require complex port forwarding that user-mode networking cannot provide).

You can control the network configuration by setting the `QEMU_NET_TYPE` environment variable:

- **`user`** (default): User-mode networking with port forwarding to host. Provides internet access and forwards guest ports 22 (SSH), 23 (Telnet), and 80 (HTTP) to host ports starting at 2200, 2300, and 8000 respectively.  See QEMU's [User Networking](https://wiki.qemu.org/Documentation/Networking#User_Networking_(SLIRP)) documentation for background info.
- **`jump`**: Connect to a jump box via socket networking. Use this mode to enable FTP file transfers through a modern Debian jump box (see [Jump Box](#jump-box) below).
- **`none`**: No networking. Useful for completely isolated testing.

### Examples

Boot with default user-mode networking:
```bash
retro slackware/3.0/walnut boot
```

Boot connected to jump box:
```bash
QEMU_NET_TYPE=jump retro slackware/3.0/walnut boot
```

Boot with no networking:
```bash
QEMU_NET_TYPE=none retro slackware/3.0/walnut boot
```

You can also set `QEMU_NET_TYPE` in a distro's `qemu.sh` configuration file to make it persistent.


## Host to VM Communication

QEMU exposes its monitor and QMP protocol via ports on the host's loopback interface. Guest serial and parallel ports are also forwarded using Unix domain sockets. When user networking is configured (see above), several guest ports are also forwarded to corresponding ports on the host.

### Port Assignment

For each listener, `retro` uses `lsof` to choose the lowest available port from the 100 port numbers starting at the base port for that service. Each port is incremented independently. The assigned ports are printed before QEMU starts.

For example, these are the default ports typically assigned to the first VM started:

```
QEMU ports:
  Monitor: 127.0.0.1:5555
  QMP:     127.0.0.1:4444

Guest ports:
  SSH:     127.0.0.1:2200 -> guest :22
  Telnet:  127.0.0.1:2300 -> guest :23
  HTTP:    127.0.0.1:8000 -> guest :80
```

Note that if you already have other services running in these port ranges, `retro` may skip ports even if another `retro` instance isn't using them. Refer to the printout at startup rather than assuming a particular port was assigned.

### Example Commands

#### QEMU Ports

Use the following commands to access the QEMU monitor and QMP protocol via the default ports:

- [QEMU monitor](https://qemu-project.gitlab.io/qemu/system/monitor.html): `telnet 127.0.0.1 5555`
- [QMP protocol](https://qemu-project.gitlab.io/qemu/interop/qemu-qmp-ref.html): `nc 127.0.0.1 4444`

Adjust the ports to those reported by `retro` at startup.

#### Guest TCP Port Forwards

Several guest services are also automatically forwarded to a host port:

- SSH: `ssh -p 2200 127.0.0.1`
- Telnet: `telnet 127.0.0.1 2300`
- HTTP: `http://127.0.0.1:8000/`

Note that a port being forwarded doesn't necessarily indicate that the guest has a service listening there. Telnet is pretty universal but SSH and HTTP servers weren't common in distros until the late 90s.

Sadly, FTP uses a complicated scheme involving random ports that makes it impossible to forward through user-mode networking. Once SSH becomes available on later distros, sftp can be used, but until then alternatives for file transfer remain cumbersome (see [Jump Box](#jump-box) below).

#### Guest Serial and Parallel Ports

Guest serial and parallel ports are exported as Unix domain sockets in the distro's `qemu.d` directory while the VM is running.

- `/dev/ttyS0`: `qemu.d/ttyS0.sock`
- `/dev/ttyS1`: `qemu.d/ttyS1.sock`
- `/dev/ttyS2`: `qemu.d/ttyS2.sock`
- `/dev/ttyS3`: `qemu.d/ttyS3.sock`
- `/dev/lp0`: `qemu.d/lp0.sock`

Connect to a serial socket with `minicom -D 'unix#ttyS0.sock'`.
Connect to the parallel socket with `nc -U qemu.d/lp0.sock`.


## Internet Access

When using `QEMU_NET_TYPE=user` (the default), the VM has outbound internet access through QEMU's SLIRP-based NAT. Keep in mind that old distributions are riddled with security holes and should never be placed on a public network. However, in this case the guest network is behind a NAT firewall which disallows incoming connections, providing some protection.

If you want to completely isolate a VM from the internet, use `QEMU_NET_TYPE=none` to disable networking entirely, but note that this will also disable port forwarding. QEMU provides an option to disable internet access while still allowing port forwarding, but for reasons currently unknown, setting `restrict=on` also breaks port forwarding and telnet connections just hang indefinitely.

Another problem is that old distros often do not support modern network protocols, so you can't do much. You *can* put an ancient distro on the internet and `ping www.google.com`, but once the novelty of that wears off, there's often little else to do. There are no web clients and the FTP client is useless behind a firewall because it doesn't support passive mode. Outbound telnet access to public servers should work, but don't forget telnet is not encrypted. Never send any confidential data or reuse passwords from any important accounts.

FTP becomes usable in later distros whose FTP client supports passive mode. Things get even more interesting in distributions that include web browsers. Old browsers without modern HTTPS ciphers can still be used with sites like [FrogFind](http://frogfind.com/), which is a search engine and web proxy that converts HTTPS sites to HTTP and rewrites the HTML to be viewable in old browsers.


## Jump Box

As a workaround for the inability to forward guest FTP servers to a host port, a jump box is provided. The `jump` script will start a modern Debian VM that can function as a file transfer bridge between host and guest. It is configured with two network interfaces that provide both host-to-guest transfers via SFTP/SCP and guest-to-guest transfers via FTP.

To use the jump box with a retro VM, start the jump box first, then start your retro VM with `QEMU_NET_TYPE=jump`:

```bash
# Terminal 1: Start the jump box
./jump run

# Terminal 2: Start retro VM connected to jump box
QEMU_NET_TYPE=jump retro slackware/3.0/walnut boot
```

Note that multiple retro guests cannot connect to the jump box simultaneously. If you start multiple retro VMs with `QEMU_NET_TYPE=jump`, networking may stop working, and you'll have to stop all the retro guests and then restart only one.

The jump box's SSH port is forwarded to `2222` on the host by default, and convenience commands are provided to ssh, sftp, and scp. Set `JUMP_SSH_PORT` to use a different host port if needed. The username and password is `retro`/`retro`.

```
Usage: jump COMMAND ...

Commands:
  run     start the jump box with a serial console
  ssh     ssh into jump box
  sftp    sftp into jump box
  scp     scp file into jump box

Additional parameters are passed verbatim to ssh/sftp/scp.
For scp, 'retro:*' is expanded to 'retro@localhost:*'.
```

On the retro guest, run `ftp 10.0.2.1` to reach the FTP server. The FTP server is configured to support both anonymous and user-based FTP (username/password: `retro`/`retro`).

To shut down the jump box, run `sudo poweroff` from the serial console or ssh session.


### Port and Serial Overrides

Override the above ports with:

- `QEMU_SERIAL_SOCKET_COUNT`: number of serial sockets to expose (default: 4)
- `QEMU_SERIAL_SOCKET_PREFIX`: serial socket filename prefix (default: `ttyS`)
- `QEMU_PARALLEL_SOCKET_COUNT`: number of parallel sockets to expose (default: 1)
- `QEMU_PARALLEL_SOCKET_PREFIX`: parallel socket filename prefix (default: `lp`)
- `QEMU_MONITOR_BASE`: base QEMU monitor port (default: 5555)
- `QEMU_MONITOR_PORT`: explicit QEMU monitor port (set to `none` to disable)
- `QEMU_QMP_BASE`: base QMP protocol port (default: 4444)
- `QEMU_QMP_PORT`: explicit QMP protocol port (set to `none` to disable)
- `QEMU_SSH_BASE`: base guest TCP port 22 host forward (default: 2200)
- `QEMU_SSH_PORT`: explicit guest TCP port 22 host forward (set to `none` to disable)
- `QEMU_TELNET_BASE`: base guest TCP port 23 host forward (default: 2300)
- `QEMU_TELNET_PORT`: explicit guest TCP port 23 host forward (set to `none` to disable)
- `QEMU_HTTP_BASE`: base guest TCP port 80 host forward (default: 8000)
- `QEMU_HTTP_PORT`: explicit guest TCP port 80 host forward (set to `none` to disable)


### QMP CLI Tool

The `qmp` helper script is a CLI tool for interacting with the functions
defined in `retrolib/qmp.sh`. It connects to `127.0.0.1:4444` by default.
Set `QMP_PORT`, `QEMU_QMP_PORT`, or `QEMU_QMP_BASE` to use a different
QMP port. When multiple VMs are running, use the QMP port printed by `retro`
when that VM started.

- `qmp dump-screen`: dump the full VGA text memory range as text.
- `qmp dump-screen -n`: prefix rows with line numbers.
- `qmp send-key ret`: send a literal QEMU sendkey key sequence.
- `printf 'ramdisk' | qmp send-stdin`: type stdin into the VM.
- `qmp send-text -n 'ramdisk'`: type text into the VM and press ENTER.
- `qmp change-image root.img`: change the default floppy drive image.
- `qmp eject-disk`: eject the default floppy drive image.


## Adding Distros

To add support for a new distro, create a new `distro/version/variant` configuration directory.  Configuration files should address the following steps.  Look at the existing distros for examples of how to do this.

### Downloading

Downloads are configured using one of the following files, in order of precedence:

- `download.sh` executes as a general script to handle special cases.
- `download.txt` contains a list of files to download in the format `filename url` with one file per line.
- `slackmirror.txt` contains the version to download from Slackware's [official mirror](https://mirrors.slackware.com/slackware/).
- `debmirror.txt` contains the Debian release directory to download from the [Debian archive dists tree](https://archive.debian.org/debian/dists/).

### Extraction

Extraction is configured by files in the distro's config directory:
- `cdrom.txt` specifies the CD-ROM that the distro comes from, relative to the `cdrom` directory.
- `extract.sh` performs distro-specific extraction...
  - If the distro doesn't support installing from an IDE CD-ROM, extract package files to the `install` directory. This will be mounted as a FAT partition to `/dev/hdb1`.
  - If a boot floppy is required, copy it to `boot.img`.
  - If a root floppy is required, copy it to `root.img`.
  - Extract any additional files required for installation.

### Preparation

The `retro` script configures QEMU to run a distro by doing the following:

1. Sets `QEMU_*` variables with the default hardware configuration and creates symlinks to attach installation files to the appropriate device:
   - `boot.img` -> `fda.img`: first floppy drive (`/dev/fd0`)
   - `root.img` -> `fdb.img`: second floppy drive (`/dev/fd1`)
   - `install` -> `hdb`: FAT partition on second IDE drive (`/dev/hdb1`)
   - `disc1.iso` -> `hdc.img`: CD-ROM drive (`/dev/hdc`)
2. Sources the distro's `qemu.sh` file if it exists. This file should:
   - Override `QEMU_*` variables for non-default hardware configuration
   - Create symlinks for any additional files needed by the installation
   - Perform any special-case initialization required by the distro
3. Creates main hard drive image `hda.img` with size `QEMU_HD_SIZE` and format `QEMU_HD_FORMAT`

### Automatic Installation and Configuration

Support may optionally be provided for automatically installing and configuring a distro. Refer to the README in the [autoinst](autoinst) directory for more information.

### Scripting Installs

If a config directory contains `script.sh`, `retro install` starts QEMU, initializes
QMP, then sources that script to drive the installer. These scripts are not
standalone entry points; they call functions from `retrolib/qmp.sh` and
`retrolib/script.sh`.

Common install-script helpers include:

- `script_boot_lilo [PROMPT]`: wait for the boot prompt and press ENTER. `PROMPT` defaults to `boot:`.
- `script_answer_prompt PROMPT [ANSWER]`: wait for screen text and send answer (or just ENTER if no answer provided).
- `script_change_floppy PROMPT [IMAGE] [ANSWER]`: wait for screen text, change the first
  floppy image, optionally type answer text, then press ENTER. `IMAGE` defaults to `root.img`.
- `script_login PROMPT [USER]`: wait for a login prompt and type the username followed by ENTER.
  `USER` defaults to `root`.
- `script_run_autoinst PROMPT`: wait for specified shell prompt on screen, mount `/dev/hdb1` at
  `/retro`, and run `/retro/autoinst`.
- `script_finish_reboot [DISK] [PROMPT] [TIMEOUT]`: wait for the final reboot prompt,
  set the next boot disk with `boot_set`, then press ENTER. `DISK` defaults to `c`,
  `PROMPT` defaults to `Press ENTER to reboot.`, and `TIMEOUT` defaults to `600`.


## Credits

- [QEMU Advent Calendar](https://www.qemu-advent-calendar.org/2014/) for giving me the idea to start playing with this.  Slackware 1.0 is Day 1 from 2014.
- [Archive.org](https://archive.org/) for keeping around all the old CD-ROM and floppy images of distros gone by.
- [Joshua Powers](https://powersj.io/posts/ubuntu-qemu-cli/) for instructions on running an Ubuntu cloud image in QEMU.


## License

Unless otherwise noted, the scripts in this repo are under MIT license.

Copyright 2022, 2026 J.B. Langston

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

### Reference Scripts

The scripts in the reference directory are a notable exception and retain their original license. License headers have been kept intact if present. Debian 1.1+ scripts do not contain license headers but are assumed to be GPL.