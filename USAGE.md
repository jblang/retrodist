# Using Retro Distro Playground

This guide collects the practical details for downloading, installing, and
working with the virtual machines. For a quick introduction and a suggested
tour through the collection, start with the [README](README.md).

## One-Time Setup

Install a Unix-like environment first:

- Linux: apt, dnf, and pacman are supported.
- macOS: install [Homebrew](https://brew.sh/).
- Windows: use [MSYS2](https://www.msys2.org/) or WSL2 with a Linux distro.

Run the prerequisite installer once from the repository root:

```bash
./retro-prereq
```

`retro-prereq` installs the host programs retrodist needs, creates `.venv`, and
installs the Python project. You only need to run it once.

## Starting a Shell

Activate the virtual environment in each new shell:

```bash
source .venv/bin/activate
```

## Commands

`retro` accepts a command and an optional config directory. The directory
defaults to the current working directory.

```text
retro boot CONFIG       download, prepare, and boot a distro
retro install CONFIG    boot and run a scripted install when supported
retro extract CONFIG    prepare downloaded media in CONFIG/qemu.d
retro download CONFIG   download original media only
retro reset CONFIG      remove generated VM state
retro package CONFIG    build a portable qemu.d archive
retro tagfile CONFIG    regenerate Slackware's default package tagset
```

`boot` and `install` automatically download and prepare their media. Running
`retro` without a command prints the built-in help.

The standalone `qmp` command controls a running VM. It can inspect the VGA text
screen, type text, press keys, and swap removable media:

```text
qmp dump-screen
qmp send-text -n 'root'
qmp send-key ret
qmp change-image root.img
qmp eject-disk
```

Run `qmp --help` for the complete command list.

## Generated State and Starting Over

Each config keeps its downloaded source media under `download.d/` and its
prepared virtual machine under `qemu.d/`. CD-ROM-backed configs may link shared
media into `qemu.d/` instead.

Recursive mirror downloads write a `.complete` marker after `wget` succeeds.
retrodist prints the marker's path when it skips a completed download; remove
that file if you want to fetch the mirror again.

Use `retro reset CONFIG` to discard a config's generated VM state and start its
extraction or installation over. Downloaded source media is kept, so it does
not normally need to be fetched again.

## Booting and Installing

Use `retro install` when a recipe supports automation:

```bash
retro install slackware/2.3/walnut
```

Installation is a one-time operation for that virtual machine. Once it
completes, use only `retro boot` for normal visits to the installed system:

```bash
retro boot slackware/2.3/walnut
```

You can also use `retro boot` before installation to work through the original
installer yourself.

Some early installers ask for several floppy disks. Change them from another
terminal with `qmp change-image IMAGE`. The nearest distro README calls out any
release-specific sequence.

Always run `halt` as `root` before closing the VM, then wait for the guest to
report that it has halted. Older systems usually cannot power off the emulated
machine themselves; after they halt, close the QEMU window or press `Ctrl-C` in
the terminal where you ran `retro`. Closing QEMU first can corrupt the guest
filesystem.

Slackware automated installs support different package selections. See
[Slackware package selection](slackware/README.md#package-selection).

For login credentials and a quick tour of commands inside the guests, see
[After the Install](README.md#after-the-install).

## Networking and Safety

VMs use QEMU user-mode networking by default. Guests can make outbound
connections, while unsolicited incoming connections are blocked. When QEMU
starts, the `retro` command prints the loopback ports it forwards; the default
ranges begin at:

- SSH: port `2200`
- Telnet: port `2300`

These guests contain decades-old software with known vulnerabilities. Do not
store sensitive information in them, expose forwarded ports on public
interfaces, or use them as a security boundary.

Config authors can customize forwarding in `config.toml`:

```toml
[qemu.network]
forwards = [[8080, 80], [2200, 22]]
```

An empty `forwards` array disables forwarding. Setting `enabled = false` in the
same table removes the guest network adapter. See
[CONTRIBUTING.md](CONTRIBUTING.md#qemu) for the complete QEMU configuration
reference.

## Moving Files In and Out

Configs with a `qemu.d/fat/` directory expose it to the guest as a writable FAT
disk, usually as `/dev/hdb1`. If it does not exist yet, create it before
booting.

For host-to-guest transfer, place files in `qemu.d/fat/`, boot the VM, mount the
FAT disk, and copy them onto the guest filesystem. For guest-to-host transfer,
copy files onto the mounted FAT disk, shut the guest down cleanly, and then read
them from `qemu.d/fat/` on the host.

Use a tar archive for Unix files so permissions, owners, symlinks, and case are
preserved:

```bash
tar -cf qemu.d/fat/files.tar path/to/files
```

Inside the guest:

```sh
mount -t msdos /dev/hdb1 /mnt
tar -xf /mnt/files.tar
```

Avoid modifying `qemu.d/fat/` from the host while the VM is running. Copy files
in before boot and shut the guest down before reading files back.
