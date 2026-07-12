# Host Library

`hostlib/` contains the Bash modules used by `retro`. The entry point sources
every `hostlib/*.sh` file, then dispatches the requested command. Distro configs
should use the public configuration variables and install helpers documented
here; other functions are implementation details unless a config already uses
them.

For the workflow for adding a distro, start with
[CONTRIBUTING.md](../CONTRIBUTING.md). Code that runs inside a guest is covered
by [guestlib/README.md](../guestlib/README.md).

## Architecture

The host-side code has five responsibilities:

| Area | Modules | Responsibility |
|---|---|---|
| Project commands | `prereq.sh`, `download.sh`, `extract.sh`, `qemu*.sh` | Config lookup, prerequisites, media staging, QEMU lifecycle, packaging, and reset |
| Shared support | `logging.sh` | Host-side logging |
| Install automation | `script.sh`, `script-serial.sh`, `script-dialog.sh`, `script-fdisk.sh` | Reusable control flow for distro `install.sh` manifests |
| QMP devices | `qmp.sh`, `script-kb.sh`, `script-vga.sh` | QMP transport plus keyboard and VGA-specific behavior |
| Distro support | `slackware.sh` | Slackware tagset generation and staging |

The QEMU implementation is divided by function: `qemu-config.sh` loads
defaults and distro overrides, `qemu-network.sh` manages host endpoints and
guest forwarding, `qemu-devices.sh` builds media and character devices,
`qemu-command.sh` assembles and renders command lines, and `qemu.sh`
orchestrates preparation, execution, packaging, and reset.

The QMP boundary is deliberate. `qmp.sh` owns the QMP pipe, QMP request and
response JSON, and HMP passthrough. Code outside that module calls
`qmp_hmp_command`; it does not open the pipe or decode QMP responses. Keyboard
operations belong in `script-kb.sh`, VGA text-memory operations in
`script-vga.sh`, and install-level media changes in `script.sh`. The `script-`
filename prefix groups install-automation modules; their functions retain the
device-oriented `dialog_`, `fdisk_`, `kb_`, `serial_`, and `vga_` prefixes.

`qmp_hmp_command COMMAND...` uses the QMP pipe held open by the current host
process. It accepts one or more plain HMP commands and prints their non-empty
plain-text responses in order without starting a client process per command.

The QMP pipe is one shared monitor stream for each QEMU process, so capabilities
are negotiated once and requests are serialized with a filesystem lock.
`qmp_pipe_handshake` accepts QEMU's "already complete" response, allowing the
standalone `qmp` CLI to attach safely even when a packaged launcher created the
stream.

## Compatibility

Host code supports modern GNU and BSD/macOS userlands and Bash 3.2. Avoid Bash
4 features such as associative arrays, `mapfile`, `readarray`, `wait -n`, and
`|&`. Keep external command options portable between GNU and BSD variants.

Every host module is sourced unconditionally. It should define functions and
defaults without performing work at source time. Prefix new public functions
for their owning module (`qemu_`, `qmp_`, `kb_`, `vga_`, `script_`, and so on).

## Config Resolution

Configs normally live at `distro/version/variant/`. `qemu_config_find_file FILE`
looks in the selected config directory first and then its parent, allowing a
version to share files across variants. The variant-level file wins.

`retro extract`, `retro boot`, and `retro install` build generated state in the
selected config's `qemu.d/`. Depending on the config, it can contain:

- `boot.img`, `root.img`, and `install.iso` links selected during extraction
- `hda.img`, the installed system disk
- explicitly named media such as `fda.img` or `hdc.iso`
- `fat/`, a writable FAT-backed disk normally visible as `/dev/hdb1`
- `fat/guestlib.d/`, the staged guest runtime and distro `postinst.sh`
- QMP pipe, serial, and parallel sockets used while QEMU is running

Treat `qemu.d/`, `download.d/`, and `tagfile.d/` as generated state. Edit the
source config, `hostlib/`, or `guestlib/` instead.

## Media Staging

`download.sh` implements the download mechanisms described in
[CONTRIBUTING.md](../CONTRIBUTING.md#downloads). `extract.sh` turns downloaded
media into the stable `qemu.d/` layout consumed by the `qemu*.sh` modules.

Most distro `extract.sh` files set `EXTRACT_*` variables and call
`extract_install_files`:

```bash
EXTRACT_SOURCE=slackware.iso
EXTRACT_BOOT_IMAGE=bootdsks.144/bare.i
EXTRACT_ROOT_IMAGE=rootdsks/color.gz
EXTRACT_EXTRA_IMAGES=(bootdsks.144/net.i)
EXTRACT_FAT_FILES=(kernels/bare.i/bzImage)
EXTRACT_PACKAGES=slakware
extract_install_files
```

| Variable | Meaning |
|---|---|
| `EXTRACT_SOURCE` | Archive, ISO, or directory under `download.d/`; absolute paths are accepted. Empty means `download.d/`. |
| `EXTRACT_BOOT_IMAGE` | Boot floppy to extract or copy; linked as `boot.img`. |
| `EXTRACT_ROOT_IMAGE` | Root floppy to extract or copy; linked as `root.img`. |
| `EXTRACT_EXTRA_IMAGES` | Bash array of additional images to stage in `qemu.d/`. |
| `EXTRACT_FAT_FILES` | Bash array of individual files to place in `qemu.d/fat/`. |
| `EXTRACT_PACKAGES` | Package subtree to place in `qemu.d/fat/packages/`; `.` selects the complete source. |

An ISO source is also linked as `install.iso`. Archive paths are flattened to
their basenames for image files. Use custom extraction code only when the media
layout cannot be represented by this interface.

`retro_extract` downloads media, runs the selected `extract.sh`, stages Red Hat
Kickstart data when configured, prepares `guestlib.d`, and writes
`qemu.d/.extracted`. Remove generated state with `retro reset CONFIG` before
testing extraction changes against an existing config.

## QEMU Configuration

A distro `qemu.sh` describes hardware and QEMU behavior. Begin with an
era-appropriate profile and override only what the guest requires:

```bash
QEMU_PROFILE=linux-1.2
QEMU_RAM=32M
```

| Profile | Machine | RAM | Disk | NIC | VGA |
|---|---|---:|---:|---|---|
| `default` | ISA PC | 16M | 500M | NE2000 ISA | QEMU default |
| `linux-0.99` | ISA PC | 64M | 500M | NE2000 ISA | QEMU default |
| `linux-1.0` | ISA PC | 64M | 512M | NE2000 ISA | QEMU default |
| `linux-1.2` | ISA PC | 64M | 2G | NE2000 ISA | QEMU default |
| `linux-2.0-isa` | ISA PC | 64M | 2G | NE2000 ISA | QEMU default |
| `linux-2.0` | PC | 64M | 8G | DEC Tulip | Cirrus |
| `linux-2.2` | PC | 64M | 8G | DEC Tulip | Cirrus |
| `linux-2.4` | PC | 128M | 8G | DEC Tulip | Standard VGA |

The commonly useful overrides are:

| Variable | Purpose |
|---|---|
| `QEMU_SYSTEM` | QEMU binary; default `qemu-system-i386`. |
| `QEMU_PROFILE` | Hardware profile from the table above. |
| `QEMU_MACHINE`, `QEMU_RAM`, `QEMU_SMP` | Machine, memory, and CPU overrides. |
| `QEMU_HD_SIZE`, `QEMU_HD_FORMAT` | New primary disk size and format. |
| `QEMU_HD_CREATE_OPTIONS`, `QEMU_HDA_OPTIONS` | Extra primary-disk creation and attachment options. |
| `QEMU_NET_ENABLED` | Enable guest networking; default `true`. False values such as `0`, `false`, `no`, and `off` disable it, case-insensitively. |
| `QEMU_NET_DEVICE` | Guest NIC model. |
| `QEMU_DISPLAY`, `QEMU_ACCEL`, `QEMU_EXTRA` | Display, acceleration, and additional QEMU arguments. |
| `QEMU_FDTYPE_A`, `QEMU_FDTYPE_B` | Floppy geometry globals; default `144`. |
| `QEMU_SERIAL_AUX` | Third serial device; use `msmouse` for guests that need a serial mouse. |

Environment values may override config values where supported; notably,
exported `QEMU_PROFILE` takes precedence over the distro's profile. Arguments
after `CONFIG` on `retro boot` and `retro install` are appended to the final
QEMU command.

### Drives

Files in `qemu.d/` attach by conventional name:

- `fda.img` and `fdb.img` are floppy drives.
- `hda.img` through `hdd.img` are IDE disks.
- `hda.iso` through `hdd.iso` are IDE CD-ROMs.
- directories named `fda`, `fdb`, or `hda` through `hdd` are writable
  FAT-backed drives.
- `fat/` occupies the second IDE drive when no `hdb` image, ISO, or directory
  exists.

At install time, `boot.img` and `install.iso` fill the first floppy and CD-ROM
slots when explicit media are absent. `hda.img` is created when startup media
exists and no primary disk has been staged.

### Display and Networking

The default display is GTK on Linux and Cocoa on macOS. Set `QEMU_DISPLAY` to a
complete display argument when another backend is required. QEMU 11 Cocoa
displays receive the supported zoom-to-fit options automatically.

Guest networking provides outbound SLIRP networking and loopback-only forwards
to guest SSH and Telnet. The default host port ranges begin at 2200 and 2300.
`QEMU_NET_FORWARD` replaces those defaults with whitespace- or comma-separated
`host:guest` port pairs; use `none` to disable all forwards. Set
`QEMU_NET_ENABLED` to a false value to omit the NIC. `QEMU_NETWORK` is an
advanced raw network override.

QEMU also exposes a loopback monitor (starting at port 5555), a QMP pipe at
`qemu.d/qmp.in`/`qemu.d/qmp.out`, serial sockets for `ttyS0` and `ttyS1`, a
dedicated install automation pipe on `ttyS3`, and a parallel socket for `lp0`.
Startup output is the authority for assigned ports and paths because occupied
host ports are skipped.

## Install Automation

During `retro install`, QEMU runs in the background while the selected distro
`install.sh` is sourced. The manifest composes device-scoped and protocol-
scoped helpers; it should not access QMP or serial pipes directly.

### Screen and Keyboard

Use VGA waits to establish state before sending input:

```bash
vga_wait -l "boot:"
kb_send_line "ramdisk root=/dev/fd0"
vga_wait -r '^Insert.*root disk'
script_change_floppy root.img
kb_press_key ret
```

Public helpers:

- `vga_wait [-l | -r] [-t SECONDS] TEXT...` waits for each screen match in
  order. `-l` matches a trimmed full line; `-r` uses an extended regex.
- `vga_dump_text` returns the decoded 80x25 VGA text screen. Override
  `VGA_ADDR`, `VGA_COLS`, `VGA_ROWS`, or `VGA_MEM_BYTES` for unusual hardware.
- `kb_press_key KEY [COUNT]` sends a QEMU key token such as `ret`, `spc`, or
  `ctrl-alt-delete`.
- `kb_send_line TEXT` types text followed by Return. `kb_send_string TEXT` and
  `kb_send_raw CODE` provide lower-level input when needed.

`WAIT_INTERVAL` controls polling and defaults to 0.1 seconds.

### Install Flow and Media

- `script_import HELPER` sources a helper relative to the active `install.sh`.
- `script_change_image IMAGE [DEVICE [FORMAT]]` replaces media, defaulting to
  raw media in `floppy0`.
- `script_eject_disk [DEVICE]` ejects media, defaulting to `floppy0`.
- `script_change_floppy IMAGE` replaces the first floppy and allows it to
  settle.
- `script_set_boot DISK` sets the next boot order, for example `a` or `c`.
- `script_run_postinst [PASSWORD]` logs in as root and starts the staged guest
  post-install runner. Override `LOGIN_PROMPT` and `SHELL_PROMPT` for guests
  with different prompts.

### Serial Automation

`serial_*` helpers use the dedicated `ttyS3` pipe. They maintain a transcript
and avoid the repeated QMP memory dumps and key events needed for VGA control.
Prefer them for shells and installers that can redirect input and output to a
serial device.

- `serial_wait [-l | -r] TEXT...` waits for ordered serial output.
- `serial_send TEXT` writes a line to the guest.
- `serial_prompt [-r] QUESTION... ANSWER` waits for prompts and answers them.
- `serial_shell [--no-wait] COMMAND...` opens a redirected shell, runs commands,
  and closes it. The `serial_shell_start`, `serial_shell_send`, and
  `serial_shell_exit` forms support multi-phase interactions.

### Dialog Installers

`script-dialog.sh` provides the host API for installers driven by the guest-side
`dialog.sh` adapter. Config authors use `dialog_answer` in `install.sh`
manifests; maintainers of either side must preserve the labeled serial
protocol. The current Debian and Slackware drivers replace the installer's real
`dialog` binary with the adapter, which exchanges screens and answers over the
serial pipe while preserving the result expected by the installer.

The common form matches one screen by widget type and title, then sends an
answer when its `RESPONSE:` prompt appears:

```bash
dialog_answer TYPE TITLE ANSWER

dialog_answer menu "Select Keyboard" us
dialog_answer yesno "Use this partition?" yes
```

`ANSWER` must be the value expected by `dialog`, which is not always the text
shown to the user. Supply an item tag for a menu, typed text for an input box,
or a button word such as `yes`, `no`, `ok`, `cancel`, or `esc`. Use `-d` when
the displayed menu description is more stable than its tag:

```bash
dialog_answer menu "SOURCE MEDIA SELECTION" -d "CD-ROM"
```

By default, `TITLE` matches the complete `TITLE:` line. The remaining matching
and response controls are:

- `any` as `TYPE` skips the widget-type check. `msgbox` and `textbox` also match
  each other.
- `-r` before `TITLE` uses an extended regular expression. It can likewise
  follow `-i` or `-d` to make that argument a regular expression.
- `-i ITEM` requires the screen to contain a matching full menu item (tag and
  description). Use it to distinguish screens that otherwise share a title and
  type.
- `-d DESCRIPTION` finds a menu item by its displayed description and sends
  that item's tag.
- `-f FUNCTION` calls a handler with the matched title; the handler is
  responsible for completing the interaction.
- `-n` waits for the matching screen without responding.
- `-l LABEL` logs entry to and exit from a multi-screen flow.

For release-dependent or optional screens, pass multiple
`TYPE TITLE ANSWER` alternatives. `dialog_answer` handles each alternative at
most once, in the order screens arrive, and returns after the alternative
prefixed with `-x`:

```bash
dialog_answer -l "swap partition" \
    menu -r "Select (Disk|Swap) Partition" "$SWAP_PARTITION" \
    yesno "Scan for Bad Blocks?" no \
    -x yesno "Are You Sure?" yes
```

The adapter's transcript includes `TITLE:`, `TYPE:`, `TEXT:`, widget metadata,
`ITEM:`, and `RESPONSE:` lines. `dialog_answer` currently matches titles,
types, and optional items; it does not match `TEXT:`.

For maintainers, `dialog_expect [-r] TITLE TYPE ANSWER` is the single-screen
primitive: it consumes the title and type in order, then answers at
`RESPONSE:`. `dialog_answer` builds on it by selecting among alternatives from
the buffered serial transcript and rewinding before the selected responder
consumes the screen. Changes to labels, ordering, item formatting, or response
timing therefore require corresponding changes on both sides of the protocol.

See the guest library's
[`dialog.sh` documentation](../guestlib/README.md#dialogsh) for the complete
wire format, supported widgets, output routing, and runtime constraints. See
`debian/dinstall.sh` and `slackware/pkgtool.sh` for maintained API examples.

`fdisk_swap_root DEVICE SWAP_MB` opens a serial shell and runs `fdisk` itself.
When an installer has already started `fdisk`, `fdisk_partitions SWAP_MB`
drives its prompts directly. Both create swap followed by a root partition
using the cylinder ranges reported by the guest's `fdisk`.

## QMP Utility

The top-level `qmp` command exposes useful device operations against a running
VM without exposing the transport API:

```bash
qmp dump-screen [-n]
qmp send-key ret
qmp send-text -n 'root'
printf 'root\n' | qmp send-stdin
qmp change-image [-d DEVICE] root.img
qmp eject-disk [DEVICE]
```

Run it from a config directory or its `qemu.d/`, or pass `-s PIPE`. Use
`qmp help` for command-specific options.

## Slackware Tagsets

`slackware.sh` generates and applies the `*.tag` package-selection rules used
by scripted Slackware installs. This is a distro feature rather than a general
host API. The maintained syntax, selection behavior, and `retro tagfile`
workflow are documented in
[slackware/README.md](../slackware/README.md#package-selection).
