# Jump Box

The `jump` script starts a modern Debian VM that can act as a network bridge
between the host and one retro guest. It exists for cases where `qemu.d/fat/`
is not enough and you specifically need FTP-style transfer from inside an old
guest.

For ordinary file transfer, prefer `qemu.d/fat/` and tar archives. The FAT disk
works without guest networking, and tar preserves Unix filenames, permissions,
owners, symlinks, and other metadata that FAT cannot represent.

## When to Use It

Use the jump box when:

- The retro guest has an FTP client and you want to pull files over the network.
- You need to test guest networking against another machine.
- The guest cannot conveniently mount or use the staged FAT disk.

Avoid it when:

- You only need to copy files in or out of a VM.
- More than one retro guest needs the bridge at the same time.
- The guest has no working network stack.

## How It Works

The jump box is a Debian cloud image configured by cloud-init. It has two
network interfaces:

- `internet0`: QEMU user-mode networking for host access and package setup.
- `retronet0`: a socket network used by one retro guest.

The host reaches the jump box with SSH, SFTP, or SCP through a forwarded local
port. The retro guest reaches the jump box FTP server at `10.0.2.1`.

The first run downloads a Debian cloud image, creates a resized working disk,
generates an SSH key pair, builds a cloud-init seed ISO, installs `vsftpd`, and
configures the FTP service.

## Quick Start

Start the jump box in one terminal:

```bash
jump run
```

Start one retro VM in another terminal:

```bash
QEMU_NET_TYPE=jump retro boot slackware/3.0/walnut
```

From the host, copy a file into the jump box:

```bash
jump scp local-file retro:
```

From the retro guest, connect to FTP:

```text
ftp 10.0.2.1
```

The FTP server supports anonymous access and user login with username/password
`retro`/`retro`.

## Commands

```text
Usage: jump COMMAND ...

Commands:
  run     start the jump box with a serial console
  ssh     ssh into the jump box
  sftp    sftp into the jump box
  scp     scp a file into or out of the jump box
```

Additional parameters are passed verbatim to `ssh`, `sftp`, or `scp`. For
`scp`, paths beginning with `retro:` are expanded to `retro@localhost:`.

Examples:

```bash
jump ssh
jump sftp
jump scp notes.txt retro:
jump scp retro:notes.txt .
```

## State Directory

Generated state lives in `jump.d/` by default:

- `id_rsa` and `id_rsa.pub`: SSH key pair used by the helper commands.
- Debian cloud image downloads.
- The resized jump box working disk.

`jump.d/` is gitignored and should not be shared or backed up into public
artifacts because it contains a private SSH key.

Set `JUMPHOME` to store this state elsewhere:

```bash
JUMPHOME=/path/to/retrodist-jump jump run
```

Use the same `JUMPHOME` value for `jump ssh`, `jump sftp`, and `jump scp`.

## Configuration

`JUMP_SSH_PORT` sets the host port forwarded to the jump box's SSH service.
The default is `2222`.

```bash
JUMP_SSH_PORT=2223 jump run
JUMP_SSH_PORT=2223 jump ssh
```

`JUMP_IMAGE_FLAVOR` selects the Debian cloud image flavor. The default is
`generic`.

`JUMP_RETRONET` overrides the QEMU socket network arguments used for the retro
guest side. The default listens on TCP port `1234`.

`QEMU_NET_DEVICE_RETRONET` overrides the emulated NIC model used by the jump
box on its retro-facing network. The default is `e1000`.

## Platform Notes

The helper chooses a QEMU system binary and machine based on the host:

- Linux: `qemu-system-x86_64` with KVM when available.
- macOS Intel: `qemu-system-x86_64` with HVF.
- macOS Apple Silicon: `qemu-system-aarch64` with HVF and Homebrew's AArch64
  EDK2 firmware.
- Other hosts: `qemu-system-x86_64` with TCG.

The first run needs network access to download the Debian cloud image. It also
needs `qemu-img`, `wget`, `ssh`, `scp`, `sftp`, and an ISO builder such as
`xorriso`, `mkisofs`, or macOS `hdiutil`.

## Limitations

Only one retro guest should connect to the jump box at a time. If multiple
retro guests use `QEMU_NET_TYPE=jump`, networking may stop working; shut down
the guests and restart only one.

The jump box FTP service is plain FTP. Do not use it for sensitive data or real
credentials. It is intended for local throwaway VM transfer workflows.

Old FTP clients vary widely. Some may require active-mode FTP, some may not
handle DNS, and some may have limited filename support. Use the numeric address
`10.0.2.1` from the retro guest.

## Shutdown

Shut down the jump box from its serial console or an SSH session:

```bash
sudo poweroff
```

Then stop any retro guest using `QEMU_NET_TYPE=jump`.

## Troubleshooting

If `jump run` reports that the SSH port is already in use, choose another port:

```bash
JUMP_SSH_PORT=2223 jump run
```

If `jump ssh` cannot connect immediately after first boot, wait for Debian
cloud-init to finish and try again.

If the retro guest cannot reach `10.0.2.1`, confirm that the jump box was
started first and that only one retro guest is using `QEMU_NET_TYPE=jump`.

If the Debian image needs to be rebuilt, stop the jump box and remove or move
the generated `jump.d/` directory. This discards the generated SSH key and
working disk.
