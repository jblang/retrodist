# Contributing

This guide covers adding or maintaining distro configs. For host-side library
details, see [retrolib/README.md](retrolib/README.md). For scripts that run
inside old installer environments, see [autoinst/README.md](autoinst/README.md).

## Add a Distro

1. Create a `distro/version/variant/` directory.
2. Add download metadata with `download.txt`, `slackmirror.txt`,
   `debmirror.txt`, `download.sh`, or `cdrom.txt`.
3. Add `extract.sh` to stage install media into `qemu.d/`.
4. Add `qemu.sh` to select an era-appropriate QEMU profile and hardware.
5. Add `script.sh` when the install can be driven through QMP.
6. Add `autoinst.sh` when installation work runs through the in-guest runtime.
7. Optionally add `autoconf.sh` for first-boot configuration.
8. Add a distro README when there are release-specific notes an end user should
   know before booting or installing.

`slackware/3.0/walnut/` is a compact working example.

## Config Files

Configs live at `distro/version/variant/`. Most config files may also live one
directory up at `distro/version/` to be shared by variants. The variant file
wins when both exist.

Common files:

| File | Purpose |
|---|---|
| `config.sh` | Distro-wide settings loaded before QEMU config |
| `download.txt` | `filename url` pairs for `wget` |
| `slackmirror.txt` | Slackware version for official mirror download |
| `debmirror.txt` | Debian release name for archive.debian.org download |
| `download.sh` | Custom download logic |
| `cdrom.txt` | Reference to a `cdrom/` config |
| `extract.sh` | Stages install images, packages, and FAT files |
| `qemu.sh` | Sets QEMU profile, RAM, disk, network, and extra args |
| `script.sh` | Host-side scripted install sequence |
| `autoinst.sh` | In-guest install manifest |
| `autoconf.sh` | Optional in-guest first-boot configuration manifest |
| `*.tag` | Slackware package-selection tagset |

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

See [retrolib/README.md](retrolib/README.md#extractsh) for the full
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
`qemu.sh`. See [retrolib/README.md](retrolib/README.md#qemush) for profiles,
drive attachment rules, network modes, and all `QEMU_*` variables.

## Scripted Installs

If a config or its parent contains `script.sh`, `retro install` starts QEMU,
initializes QMP, then sources that script to drive the installer. These scripts
are not standalone entry points; they call functions from `retrolib/qmp.sh` and
`retrolib/script.sh`.

The usual flow is to wait for known screen text, send a key or line, and repeat:

```sh
screen_wait -l "boot:"
kb_send_line ""
screen_wait -l "login:"
kb_send_line root
serial_shell --no-wait "$SCRIPT_AUTOINST_COMMAND"
serial_wait -l "ATTN: Press ENTER to reboot."
script_set_boot c
serial_send ""
```

Useful primitives:

- `screen_wait [-l | -r] [-t SECONDS] TEXT [TEXT ...]`
- `serial_shell [--no-wait] COMMAND [COMMAND ...]`
- `serial_wait [-l] TEXT [TEXT ...]`
- `serial_send TEXT`
- `kb_press_key KEY [COUNT]`
- `kb_send_line TEXT`
- `script_change_floppy IMAGE`
- `script_set_boot DISK`

`SCRIPT_AUTOINST_COMMAND` mounts the staged FAT media at `/retro` and runs
`/retro/autoinst`. Send it with `serial_shell --no-wait` once the installer
has reached a shell prompt, then match its output with `serial_wait` and
answer with `serial_send`. Override `SHELL_PROMPT` when a guest uses
non-default shell prompt text.

Slackware 1.1.2 and up (`slackware/pkgtool.sh`) replace the guest's `dialog`
binary with the `autoinst/dialog.sh` adapter. The host-side helpers live in
`retrolib/dialog.sh`: `dialog_answer` takes `TYPE TITLE ANSWER` triples. A
single triple answers one expected screen; multiple triples answer screens
that vary by version in stream order, ended by a triple prefixed with `-x`,
which answers that screen and then returns. Prefix a TITLE with
`-r` to match it as an extended regex, and replace ANSWER with `-f HANDLER` to
run a handler function that receives the matched title and answers the screen
itself. Use `any` for the type only when the screen has no `TYPE:` line.
`-l LABEL` logs entry and exit of the alternative set under that label;
without it nothing is logged.
Use `-i ITEM` after a title to require a menu item line containing ITEM before
that alternative matches (`-i -r` for a regex match).
Use `-n` where an alternative should match without sending a response; it
takes no answer argument.
For menus whose item keys vary by version, replace ANSWER with `-d TEXT` to
send the key of the item whose displayed text contains TEXT (`-d -r` for a
regex match).

Slackware 1.01 and 1.0beta use `slackware/sysinstall.sh` to drive their original
SLS-style `doinstall` scripts over serial after partitioning with the shared
`script_fdisk_partitions` helper.

## In-Guest Autoinstall

`autoinst.sh` is the install manifest copied into the guest runtime. It should
set disk, package, and install variables, then call wrappers from
`autoinst/common.sh`, such as `disk_init` or `sls_sysinstall`.

`autoconf.sh` is optional first-boot configuration. Configure kernel modules
with `MOD_ENABLE` plus `mod_config`, and configure networking separately with
`net_config`.

See [autoinst/README.md](autoinst/README.md) for runner behavior, wrapper
functions, portability constraints, and the warning about reference files versus
generated `qemu.d/` copies.

## Slackware Tagsets

Slackware 1.1.1 and later automated installs choose packages with `*.tag`
files. See [slackware/README.md](slackware/README.md#package-selection) for
tagset syntax and user-facing selection examples.

A variant-level tagset shadows a same-named version-level tagset. Run
`retro tagfile slackware/<version>/<variant>` to regenerate `default.tag` from
the install media.

## Generated Files

Do not edit files under `qemu.d/fat/autoinst.d/` directly. They are generated
copies staged for automated installs.

Edit the source files instead:

- `autoinst/` for shared install and configuration helpers.
- `slackware/VERSION[/VARIANT]/autoconf.sh` for Slackware first-boot manifests.
- `debian/VERSION/autoconf.sh` for Debian first-boot manifests.
- The relevant distro config directory for `script.sh`, `qemu.sh`,
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
