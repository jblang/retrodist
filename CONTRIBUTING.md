# Contributing

This guide is the main reference for adding and maintaining distro configs.
The Python commands `retro` and `qmp` are the supported workflow, and
configuration belongs in `config.toml`.

For day-to-day commands and VM operation, see [USAGE.md](USAGE.md).
For subsystem boundaries and installer control flow, see
[ARCHITECTURE.md](ARCHITECTURE.md).
For code that runs inside old guests, see [guestlib/README.md](guestlib/README.md).

## Add a Distro

1. Create `distro/version/variant/` and add `config.toml`.
2. Describe downloads in `[download]`.
3. Describe staging in `[extract]`.
4. Select emulated hardware in `[qemu]` and its nested tables.
5. Add `[install]` when an automated installer is supported.
6. Add `[postinst]` for installed-system configuration.
7. Add release notes to the nearest README when users need special instructions.

Use `slackware/3.0/walnut/` as a compact example. Prefer extending an existing
installer-family driver when releases share the same installer.

## Configuration Loading

Each selected config must have a `config.toml` locally or in its immediate
parent. The selected config inherits values from that parent. Child scalars and
arrays replace inherited values, while nested tables retain inherited keys that
the child does not override. Lookup does not continue above the immediate
parent.

Organize TOML by concern:

```toml
[download]
cdrom = "walnut/slackware/3.0"

[extract]
source = "disc1.iso"
boot_image = "bootdsks.144/idecd"
root_image = "rootdsks/color.gz"

[qemu]
profile = "linux-1.2"

[install]
driver = "slackware-dialog"
variant = "3.0"

[install.network]
hostname = "darkstar"
domain = "retro.net"

[postinst]
stages = ["tty", "x11"]
```

Unknown settings and incorrectly typed values are errors. When adding a new
setting, update its Python model or validator and add unit coverage.

## Downloads

`retro download CONFIG` supports these `[download]` settings:

- `cdrom`: config name below `cdrom/`; its downloaded ISO files are linked into
  the selected config's `qemu.d/`.
- `slackware_mirror`: version directory from the official Slackware mirror.
- `debian_mirror`: release name from `archive.debian.org`.
- `files`: array of `{ path, url }` tables.

Example:

```toml
[download]
slackware_mirror = "1.01"

[[download.files]]
path = "disc1.iso"
url = "https://archive.org/download/example/disc1.iso"
```

Paths are relative and may include directories. Non-CD-ROM media is stored in
the config's `download.d/`; CD-ROM-backed configs use linked media in `qemu.d/`.
Successful recursive mirror downloads write `.complete` in the mirrored
directory. Remove that file to retry the download. Absolute paths, parent
traversal, and unsafe mirror release identifiers are rejected. An existing
direct-download target is reused; a partial target is removed after failure.

## Extraction

`retro extract CONFIG` downloads media, stages it in `qemu.d/`, refreshes the
guest library, and writes `qemu.d/.extracted`.

The standard `[extract]` table supports:

- `source`: an ISO, tar, 7-Zip, or ZIP archive, directory, or downloaded
  source path. Its file type selects the extraction library automatically.
- `boot_image` and `root_image`: boot and root media staged at the top of
  `qemu.d/` and linked to their conventional names.
- `extra_images`: additional disk images or image glob patterns staged at the
  top of `qemu.d/`.
- `files`: non-image files or glob patterns staged at the top of `qemu.d`.
- `fat_files`: files staged in `qemu.d/fat/`.
- `package_source`: one package directory tree within the extraction source.
- `package_sources`: multiple package trees merged at the destination; use this
  for archives split between trees such as `binary-i386` and `binary-all`.
- `package_index`: Debian `Packages` or `Packages.gz` index within the
  extraction source, staged and parsed while generating the package installer.
- `package_dest`: destination beneath `qemu.d/fat/`; defaults to `packages`.
- `decompress`: staged gzip files or glob patterns to decompress.
- `truncate`: staged floppy files or glob patterns to normalize to 1.44 MB.
- `boot_link` and `root_link`: staged source names for `boot.img` and `root.img`.
- `overlays`: downloaded files copied over paths in the staged tree.
- `custom_script`: exceptional hook, run after selected source media is staged
  and before declarative postprocessing.

Source selectors are relative to `source`; absolute and parent-traversal paths
are rejected. Custom scripts are resolved from the selected config directory
and then its immediate parent, so variants may share a hook. `package_source`
and `package_sources` are mutually exclusive.

Example:

```toml
[extract]
source = "disc1.iso"
boot_image = "bootdsks.144/bare.i"
root_image = "rootdsks/color.gz"
extra_images = ["rootdsks/text.gz"]
fat_files = ["kernels/bare.i/bzImage"]
package_source = "slakware"
decompress = ["*.gz"]
boot_link = "bare.i"
root_link = "color"
```

Python selects the declared files and package tree from ISO, tar, ZIP, and
7-Zip sources, then runs a `custom_script = "extract.sh"` if configured, and
finally applies overlays, links, and postprocessing. Use hooks only for media
conversion that Python cannot express. Hooks run from `qemu.d/`, write final
media there directly, and stop at the first failing command. A hook-produced
`install.iso` is preserved; otherwise, ISO sources are linked from the
configured extraction source.

Declare downloaded-file replacements as tables. Relative sources start in the
effective download directory (`download.d/`, or `qemu.d/` for a shared CD-ROM
recipe); destinations must remain beneath `qemu.d/`:

```toml
[[extract.overlays]]
source = "fixed/kernel.img"
destination = "boot/kernel.img"
```

Extraction hooks receive these paths and command details:

| Variable | Value |
| --- | --- |
| `RETRO_D` | Repository root. |
| `GUESTLIB_D` | Source `guestlib/` directory. |
| `DISTRO_D` | Selected config directory. |
| `QEMU_D` | Selected `qemu.d/`. |
| `DOWNLOAD_D` | Effective download directory. |
| `TAGFILE_D` | Selected `tagfile.d/`. |
| `CONFNAME` | Config name relative to the repository when possible. |
| `COMMAND` | Active `retro` command. |

If `ks.cfg` exists in the selected config or its immediate parent, extraction
strips blank and comment lines and injects it into an existing `boot.img` as
`::ks.cfg`. Keep Kickstart policy in that source file; no extraction hook is
needed.

## QEMU

Select an era profile and override only settings used by an existing distro:

```toml
[qemu]
profile = "linux-1.2"

[qemu.disk]
size = "2G"

[qemu.network]
device = "ne2k_isa"
enabled = true
forwards = [[2200, 22], [2300, 23]]

[qemu.serial]
auxiliary = "null"
```

Available profiles are `default`, `linux-0.99`, `linux-1.0`, `linux-1.2`,
`linux-2.0-isa`, `linux-2.0`, `linux-2.2`, and `linux-2.4`. Profiles fix the
machine, RAM, default disk size, network adapter, and VGA model. Python assigns
loopback SSH and Telnet forwards from the ranges starting at ports 2200 and
2300. Omitting `forwards` selects those automatic forwards; an explicit empty
array keeps guest networking but disables forwarding. Set `enabled = false` to
omit the guest NIC entirely. The runtime uses the project-wide QEMU system,
disk format, display, acceleration, floppy geometry, and install-media-derived
boot order.

The stager supplies conventional `boot.img`, `root.img`, `install.iso`, and FAT
media. See [Media Staging](ARCHITECTURE.md#media-staging) for the complete
filename contract.

## Automated Installation

Set `install.driver` to one of the family or focused drivers registered in
`hostlib/install/__init__.py`:

| Driver | Supported `variant` values | Required driver-specific data |
| --- | --- | --- |
| `debian-dialog` | `1.1`, `1.2`, `1.3`, `1.3-vfat` | `variant` |
| `debian-091` | None | None beyond `driver` |
| `slackware-dialog` | `1.1.2`, `2.0`, `2.1`, `2.2-2.3`, `3.0`, `3.1-3.4`, `3.5-4.0`, `7.0-7.1`, `8.0-9.0` | `variant` |
| `slackware-sysinstall` | None | None beyond `driver` |
| `slackware-tty` | None | None beyond `driver` |
| `redhat-dialog` | `1.1`, `2.1`, `3.0.3` | `variant`, `install.packages.package_series` |
| `redhat-newt` | `4.0`, `4.1`, `4.2`, `5.0`, `5.1` | `variant`, `install.packages.components` |
| `redhat-unattended` | None | `install.boot.command`, `install.completion.prompt` |

Family-driver settings are grouped into topical tables such as
`install.accounts`, `install.disk`, `install.network`, `install.locale`, and
`install.packages`. Pydantic validates the complete driver-discriminated
configuration, and family drivers consume those typed sections directly. Major
drivers use `install.variant` to select a Python-defined profile that owns fixed
screen sequences, boot prompts, and installer quirks. See the existing configs,
`hostlib/schemas/`, and `hostlib/install/` for supported values. Use a
release range or descriptive name when several releases share the same profile.

Common tables have stable meanings, although each driver exposes only the
tables present in its schema:

| Table | Typical settings |
| --- | --- |
| `install.disk` | Target disk, swap/root/FAT partitions, FAT mount point and filesystem, and optional `swap_mb`. |
| `install.locale` | Hardware clock mode, keymap, and timezone. |
| `install.network` | Canonical static network values; Debian also accepts module name and arguments. |
| `install.accounts` | Root and optional user credentials supported by that family. |
| `install.packages` | Slackware series/source/tagfile path or required Red Hat package selections. |
| `install.prompts` | Boot input/timing and an optional post-install screen prompt for families that use the shared schema. |

Debian dialog installs use `install.boot` for boot and root-floppy prompts.
Unattended Red Hat installs use `install.boot`, `install.completion`,
`install.accounts`, and `install.prompts` with their dedicated schemas.

Red Hat and Slackware install-time package selection belongs under
`[install.packages]`. Debian installs additional packages after the base system,
so its package selection remains under `[postinst.packages]`.

The default swap partition size matches the selected QEMU profile's memory.
Set `install.disk.swap_mb` only when a release needs a deliberate override.

For example, a Slackware config selects its release workflow and keeps package
selection declarative:

```toml
[install]
driver = "slackware-dialog"
variant = "3.0"

[install.packages]
package_sets = '"A" "AP" "N" "X" "XAP"'
tagfile_path = "/retro/tagfiles"
```

Keep screen sequences, prompt answers, and branching in
`hostlib/install/`. Extend a family driver when releases share a workflow;
add a focused Python driver for a genuinely one-off installer. TOML should
contain only the release-specific values consumed by the driver's typed schema.
The dedicated `debian_091.py` and `slackware_tty.py` drivers are compact
examples.

### Adding installer support

For a new release in an existing family:

1. Add or reuse a variant profile in the family driver.
2. Add the variant name to the corresponding schema `Literal`.
3. Keep configurable values in the existing typed topical tables.
4. Add schema and workflow coverage to `tests/test_python.py`.

For a genuinely new driver:

1. Define its strict config model under `hostlib/schemas/`.
2. Add the model to `InstallConfig` in `hostlib/schemas/__init__.py`.
3. Implement a `run_*` entry point under `hostlib/install/`.
4. Register that entry point in `hostlib/install/__init__.py`.
5. Add configuration, dispatch, and workflow tests before adding recipes.

## Post-Installation Configuration

`[postinst]` is converted during staging to
`qemu.d/fat/guestlib.d/distro/config.sh`. The guest runner sources that file
and executes `stages` in order. Supported stages are `packages`, `modules`,
`network`, `tty`, `x11`, and `custom`.

| Stage | Purpose | Requests reboot |
| --- | --- | --- |
| `packages` | Run the generated Debian package installer. | No |
| `modules` | Configure boot-time kernel modules. | Yes |
| `network` | Write static networking for the detected guest layout. | Yes |
| `tty` | Enable a serial login console. | Yes |
| `x11` | Write configuration for the detected XFree86 generation. | No |
| `custom` | Source the configured exceptional guest script. | Only if the script requests it |

Stages run in the declared order. `debug` controls debug logging, `log` selects
the guest log path, `fat_filesystem` overrides the filesystem used to mount the
exchange disk, and `reboot` requests a final reboot. The `modules`, `network`,
and `tty` wrappers set the reboot flag even when `reboot = false` was rendered.

```toml
[postinst]
stages = ["modules", "network", "tty", "x11"]
debug = false
log = "/postinst.log"
reboot = true

[postinst.modules]
enable = "ne io=0x300"

[postinst.network]
hostname = "darkstar"
domain = "retro.net"

[postinst.tty]
dev = "ttyS0"
baud = 9600

[postinst.x11]
chipset = "clgd5434"
mouse_device = "/dev/psaux"
```

### Debian package selection

Set `extract.package_index` to the Debian `Packages` or `Packages.gz` path
within the configured directory, archive, or ISO. Media staging extracts the
index and parses it directly when generating the installer. Enable the installer
with `packages` in `postinst.stages`. `priorities` selects those priorities
across the archive; a named `sections` entry replaces that global priority list
for its section. `add` names additional individual packages. `skip` has highest
precedence and removes a package even if it was added explicitly or is needed
as a dependency; package resolution fails if that leaves a dependency
unavailable. The selectors form a union. `Depends` and `Pre-Depends` are added
recursively; version constraints are ignored, alternatives choose the first
available package, and virtual dependencies use an available `Provides` entry.

`roots` is an ordered list of package trees. Use it when a CD index mixes
fixed and original archives; the generated guest installer uses the first tree
containing the requested package.

When package configuration is interactive, the Debian installer switches the
post-install runner to its automation serial port. Add every expected question
and response under `postinst.packages.prompts`; questions may arrive in any
order, but all configured questions must appear. An empty answer submits Enter.
Set `regex = true` when `expect` is a regular expression. Package prompts are
invalid unless `packages` is present in `postinst.stages`.

For example, Smail's local-only configuration selects option 4 and accepts the
summary:

```toml
[[postinst.packages.prompts]]
expect = "Select a number from 1 to 5"
answer = "4"

[[postinst.packages.prompts]]
expect = "Is this OK, or would you like to change the configuration?"
answer = ""
```

For an original CD-ROM, mount QEMU's `hdc` device and set `roots` to the
archive's long-filename binary directory:

```toml
[postinst]
stages = ["packages", "tty"]

[postinst.packages]
roots = ["/cdrom/buzz-fixed/binary-i386"]
priorities = ["required", "important"]
add = ["vim"]
skip = ["ex"]

[postinst.packages.sections]
devel = ["standard"]

[postinst.packages.mount]
device = "/dev/hdc"
point = "/cdrom"
filesystem = "iso9660"
# options = "ro"

[extract]
package_index = "buzz-fixed/binary-i386/Packages"
```

Official mirror variants can instead stage `binary-i386` and `binary-all`
with `extract.package_sources` into the QEMU VFAT share, preserving long
filenames. Omit `postinst.packages.mount` and use
`roots = ["/retro/packages"]` in that case. Set
`postinst.fat_filesystem = "vfat"` so the guest mounts that share with
long-filename support.

`[install.network]` and `[postinst.network]` use the same canonical static
network names: `hostname`, `domain`, `ip`, `netmask`, `network`, `broadcast`,
`gateway`, and `nameserver`. Post-install networking additionally accepts the
guestlib compatibility controls documented in `guestlib/README.md`.

Include `custom` in `stages` and set `custom_script = "postinst.sh"` only when
the guest needs logic not expressible through the standard stages. Keep
ordinary stages such as `tty` and `x11` in the array rather than invoking their
helpers from the custom script. Custom scripts must follow the portability
rules in [guestlib/README.md](guestlib/README.md). The script is resolved from
the selected config and then its immediate parent. Scalar values under
`[postinst.custom]` become uppercase shell variables in the generated config.

## Slackware Tagsets

Slackware 1.1.1 and later installs can use host-generated tagfiles. Current
staging reads only the effective `full.tag`: a selected-config `full.tag`
replaces one in its immediate parent. Other `*.tag` names are not selected by
the current schema.

Each rule is `series package state`, where state is `ADD`, `REC`, `OPT`, or
`SKP`. Use `*` as the package for a series default; an exact package rule wins.
Packages without either rule default to `SKP`. Staging inventories the package
tree or ISO and writes per-disk tagfiles plus `disksets.txt` to the FAT share.

`retro tagfile slackware/VERSION/VARIANT` regenerates `default.tag` from the
installer's original tag metadata. The command overwrites that file. Treat it
as an editable reference; to affect current automated staging, incorporate the
desired rules into the effective `full.tag`.

Under `[install.packages]`, `package_sets` selects the series offered to setup.
The 1.1.1 `slackware-tty` driver uses the tagfiles generated directly in its
staged package tree. The 1.1.2-and-later `slackware-dialog` driver additionally
accepts `tagfile_path` for a staged custom path; set it to `false` to use the
installer's own default tagfiles instead.

## Generated Files

Do not edit `qemu.d/`, `download.d/`, `tagfile.d/`, or staged
`qemu.d/fat/guestlib.d/` copies. Edit `config.toml`, `guestlib/`, custom source
scripts, `full.tag`, and source READMEs instead. `default.tag` is the intentional
source-tree output of `retro tagfile`, not generated `tagfile.d/` state.

## Validation

Run the cheap checks after source changes:

```bash
git diff --check
tests/unit.sh
tests/shellcheck.sh
black --check .
```

`tests/unit.sh` automatically uses the repository `.venv` when available.
`tests/run.sh` combines the unit and ShellCheck suites; Black remains a separate
check.

Use the narrowest relevant runtime check:

```bash
retro download CONFIG
retro extract CONFIG
retro boot CONFIG
retro install CONFIG
```

Full installs are expensive and sometimes manual. Run one when a change affects
VM interaction, installer flow, or in-guest configuration. After changing
`guestlib/` or a custom `postinst.sh`, apply the portability constraints in
[guestlib/README.md](guestlib/README.md#compatibility).
