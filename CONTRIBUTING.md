# Contributing

This guide is the main reference for adding or maintaining distro configs. For
host implementation and public automation APIs, see
[hostlib/README.md](hostlib/README.md). For code that runs inside old guests,
see [guestlib/README.md](guestlib/README.md).

## Add a Distro

1. Create a `distro/version/variant/` directory.
2. Add download metadata with `download.txt`, `slackmirror.txt`,
   `debmirror.txt`, `download.sh`, or `cdrom.txt`.
3. Add `extract.sh` to stage install media into `qemu.d/`.
4. Add `qemu.sh` to select an era-appropriate QEMU profile and hardware.
5. Add `install.sh` when the install can be driven through QMP.
6. Optionally add `postinst.sh` for post-installation configuration.
7. Add a distro README when there are release-specific notes an end user should
   know before booting or installing.

`slackware/3.0/walnut/` is a compact working example. Prefer extending an
existing version or installer-family driver when the media and prompts are
substantially shared.

## Config Files

Configs live at `distro/version/variant/`. Most files may also live one
directory up at `distro/version/` to be shared by variants. Lookup checks only
the selected directory and its parent; the selected directory wins.

Common files:

| File | Purpose |
|---|---|
| `download.txt` | `filename url` pairs for `wget` |
| `slackmirror.txt` | Slackware version for official mirror download |
| `debmirror.txt` | Debian release name for archive.debian.org download |
| `download.sh` | Custom download logic |
| `cdrom.txt` | Reference to a `cdrom/` config |
| `extract.sh` | Stages install images, packages, and FAT files |
| `qemu.sh` | Sets QEMU profile, RAM, disk, network, and extra args |
| `install.sh` | Host-side scripted install sequence |
| `postinst.sh` | Optional in-guest post-installation configuration manifest |
| `*.tag` | Slackware package-selection tagset |

The alternative Python host also recognizes `download.py`, `extract.py`,
`qemu.py`, and synchronous `install.py` manifests. Existing Bash manifests
remain authoritative for `retro`; keep both forms while the Python host is
being evaluated. Declarative `extract.sh` files are read directly by Python,
while custom extraction scripts run through the Bash compatibility path.

## Downloads

`retro download` runs every download mechanism configured for the distro. When
multiple files exist, they run in this order:

1. `download.txt`
2. `slackmirror.txt`
3. `debmirror.txt`
4. `download.sh`

For CD-ROM based configs, `cdrom.txt` names a config under [cdrom](cdrom).
`retro download` downloads that CD-ROM config first, then links the ISO files
into the distro's `qemu.d/` directory.

Non-CD-ROM downloads are stored in the config's `download.d/` directory.
CD-ROM based configs use `qemu.d/` as their original-media directory because
the ISO links are part of the staged QEMU layout.

## Extraction

`retro extract` calls `download`, creates `qemu.d/`, runs `extract.sh`, and
writes `qemu.d/.extracted`. Later runs reuse the extracted tree.

For the common case, `extract.sh` sets `EXTRACT_*` variables and calls
`extract_install_files`:

```bash
EXTRACT_BOOT_IMAGE=bootdsks.144/bare.i
EXTRACT_ROOT_IMAGE=rootdsks/color.gz
EXTRACT_PACKAGES=slakware
extract_install_files
```

See [hostlib/README.md](hostlib/README.md#media-staging) for the full
`EXTRACT_*` variable list and extraction helper reference.

## QEMU Configuration

`qemu.sh` should describe hardware and QEMU behavior only: profile, RAM, disk
size, network device, display or acceleration flags, boot order, extra QEMU
arguments, or explicit device images such as `fda.img` and `hdc.iso`.

Use `QEMU_PROFILE` first and override only what the distro needs:

```bash
QEMU_PROFILE=linux-1.2
QEMU_RAM=32M
```

General install media links should be created by `extract.sh`, not by
`qemu.sh`. See [hostlib/README.md](hostlib/README.md#qemu-configuration) for
profiles, drive attachment rules, network modes, and supported `QEMU_*`
variables.

## Scripted Installs

If a config or its parent contains `install.sh`, `retro install` starts QEMU,
initializes QMP, then sources that script to drive the installer. These scripts
are not standalone entry points; they call functions from the host-side
automation helpers in `hostlib/`. They run on the host under Bash and follow the
host compatibility rules.

The usual flow is to wait for known screen text, send a key or line, and repeat:

```sh
vga_wait -l "boot:"
kb_type -n ""
vga_wait -l "login:"
kb_type -n root
vga_wait -l "$SHELL_PROMPT"
kb_type -n "$INSTALL_POSTINST_COMMAND"
```

The main primitives are:

- `script_import HELPER`
- `vga_wait [-l | -r] [-t SECONDS] TEXT [TEXT ...]`
- `serial_shell [--no-wait] COMMAND [COMMAND ...]`
- `serial_wait [-l | -r] TEXT [TEXT ...]`
- `serial_send TEXT`
- `kb_press KEY [KEY ...]`
- `kb_repeat KEY [COUNT]`
- `kb_type [-n] TEXT`
- `script_change_image IMAGE [DEVICE [FORMAT]]`
- `script_eject_disk [DEVICE]`
- `script_change_floppy IMAGE`
- `script_set_boot DISK`

`INSTALL_POSTINST_COMMAND` mounts the staged FAT media at `/retro` if needed
and runs `/retro/guestlib.d/postinst.sh`. Send it once the guest has booted
into the installed system and reached a shell prompt. `script_run_postinst`
wraps this pattern: it waits for `$LOGIN_PROMPT`, logs in, waits for
`$SHELL_PROMPT`, and sends `$INSTALL_POSTINST_COMMAND`. Override `SHELL_PROMPT`
or `LOGIN_PROMPT` when a guest uses non-default prompt text.

Slackware 1.1.2 and up (`slackware/pkgtool.sh`) replace the guest's `dialog`
binary with the `guestlib/dialog.sh` adapter. The host-side helpers live in
`hostlib/script-dialog.sh`; `dialog_answer TYPE TITLE ANSWER` is the normal
interface.
It also supports alternatives for installer screens that vary by release.
Keep shared screen sequences in an installer-family driver and leave only
release-specific values and ordering in each `install.sh`. The
[host library guide](hostlib/README.md#dialog-installers) documents the adapter
protocol and options; `debian/dinstall.sh` and `slackware/pkgtool.sh` are the
maintained examples.

Slackware 1.01 and 1.0beta use `slackware/sysinstall.sh` to drive their original
SLS-style `doinstall` scripts over serial after partitioning with the shared
`fdisk_partitions` helper.

## Post-Installation Configuration

`postinst.sh` is an optional post-installation configuration manifest, copied
into the guest runtime and staged as `guestlib.d/distro/postinst.sh`. It is
sourced inside the installed guest and must be portable `sh`. Use `MOD_ENABLE`
with `mod_config` for kernel modules and `net_config` for networking.

A typical manifest is declarative and short:

```sh
MOD_ENABLE="tulip"
mod_config
tty_config
X11_CHIPSET=clgd5446
x11_config
```

Keep host orchestration in `install.sh`; put only commands that must run in the
installed guest in `postinst.sh` or a reusable `guestlib/` helper.

See [guestlib/README.md](guestlib/README.md) for runner behavior, wrapper
functions, portability constraints, and source-versus-generated file guidance.

## Slackware Tagsets

Slackware 1.1.1 and later automated installs choose packages with `*.tag`
files. See [slackware/README.md](slackware/README.md#package-selection) for
tagset syntax and user-facing selection examples.

A variant-level tagset shadows a same-named version-level tagset. Run
`retro tagfile slackware/<version>/<variant>` to regenerate `default.tag` from
the install media.

## Generated Files

Do not edit files under `qemu.d/fat/guestlib.d/` directly. They are generated
copies staged for post-installation configuration.

Edit the source files instead:

- `guestlib/` for shared post-installation configuration helpers.
- `slackware/VERSION[/VARIANT]/postinst.sh` for Slackware post-installation
  manifests.
- `debian/VERSION/postinst.sh` for Debian post-installation manifests.
- The relevant distro config directory for `install.sh`, `qemu.sh`,
  `extract.sh`, tagsets, and per-release notes.

## Validation

Run cheap checks after source changes:

```bash
git diff --check
tests/unit.sh
```

For config changes, run the most relevant command you can reasonably verify:

```bash
retro extract CONFIG
retro boot CONFIG
retro install CONFIG
```

Full installs are slower and may require manual VM interaction, so reserve
`retro install` for changes that affect scripted installation or in-guest
configuration.

After changing `hostlib/`, check Bash 3.2 and GNU/BSD command compatibility.
After changing `guestlib/` or a distro `postinst.sh`, apply the portability
constraints in [guestlib/README.md](guestlib/README.md#compatibility).
