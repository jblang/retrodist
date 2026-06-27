# Jump Box

`jump` starts a modern Debian VM for file transfer and network testing with one
retro guest. Use it when the FAT disk is awkward or when you specifically need
FTP from inside the guest.

For ordinary file copies, prefer `qemu.d/fat/` plus tar archives. FAT works
without guest networking; tar preserves Unix permissions, owners, symlinks, and
case-sensitive names.

## Quick Start

Start the jump box:

```bash
jump run
```

Start one retro VM on the jump network:

```bash
QEMU_NET_TYPE=jump retro boot slackware/3.0/walnut
```

Copy a file from the host:

```bash
jump scp local-file retro:
```

Fetch it from the retro guest:

```text
ftp 10.0.2.1
```

FTP supports anonymous access and the `retro`/`retro` user.

## Commands

```text
jump run      start the jump box with a serial console
jump ssh      SSH into the jump box
jump sftp     SFTP into the jump box
jump scp      copy files into or out of the jump box
```

Extra arguments go to `ssh`, `sftp`, or `scp`. For `scp`, paths beginning with
`retro:` expand to `retro@localhost:`.

```bash
jump ssh
jump sftp
jump scp notes.txt retro:
jump scp retro:notes.txt .
```

## Network Layout

The jump box has two NICs:

- `internet0`: QEMU user networking for SSH/SFTP/SCP and first-boot setup.
- `retronet0`: socket networking for one retro guest.

The host reaches SSH through a forwarded local port. The retro guest reaches the
FTP server at `10.0.2.1`.

Only run one retro guest on `QEMU_NET_TYPE=jump` at a time.

## State

Generated state lives in `jump.d/` by default:

- Debian cloud image download.
- Resized working disk.
- `id_rsa` and `id_rsa.pub` for the helper commands.

`jump.d/` is gitignored. Do not publish it; it contains a private SSH key.

Use `JUMPHOME` to put this state somewhere else:

```bash
JUMPHOME=/path/to/retrodist-jump jump run
JUMPHOME=/path/to/retrodist-jump jump ssh
```

## Configuration

- `JUMP_SSH_PORT`: host SSH forward. Default: `2222`.
- `JUMP_IMAGE_FLAVOR`: Debian cloud image flavor. Default: `generic`.
- `JUMP_RETRONET`: QEMU socket network arguments for the retro side. Default:
  TCP port `1234`.
- `QEMU_NET_DEVICE_RETRONET`: jump-box NIC model for the retro side. Default:
  `e1000`.

Example:

```bash
JUMP_SSH_PORT=2223 jump run
JUMP_SSH_PORT=2223 jump ssh
```

## Host Support

The helper picks a QEMU system binary and machine from the host:

- Linux: `qemu-system-x86_64` with KVM when available.
- macOS Intel: `qemu-system-x86_64` with HVF.
- macOS Apple Silicon: `qemu-system-aarch64` with HVF and Homebrew AArch64
  EDK2 firmware.
- Other hosts: `qemu-system-x86_64` with TCG.

First boot needs network access and these host tools: `qemu-img`, `wget`,
`ssh`, `scp`, `sftp`, and an ISO builder such as `xorriso`, `mkisofs`, or macOS
`hdiutil`.

## Shutdown

From the serial console or SSH:

```bash
sudo poweroff
```

Then stop any retro guest using `QEMU_NET_TYPE=jump`.

## Troubleshooting

- SSH port in use: set `JUMP_SSH_PORT` to another port.
- `jump ssh` fails right after first boot: wait for cloud-init and retry.
- Retro guest cannot reach `10.0.2.1`: start `jump run` first and keep only one
  retro guest on the jump network.
- Need a clean jump box: stop it and remove or move `jump.d/`. This discards
  the SSH key and working disk.

Plain FTP is not secure. Use this only for local throwaway transfer workflows.
