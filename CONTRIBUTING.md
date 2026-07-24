# Contributing

This guide is the main reference for adding and maintaining distro configs.
The Python commands `retro` and `qmp` are the supported workflow, and
configuration belongs in `config.toml`.

For day-to-day commands and VM operation, see [USAGE.md](USAGE.md).
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
driver = "slackware-pkgtool"

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
directory. Remove that file to retry the download.

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
and then its immediate parent, so variants may share a hook.

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

## QEMU

Start with a profile and override only required hardware:

```toml
[qemu]
profile = "linux-1.2"
ram = "32M"
smp = 1
boot_order = "order=a"
extra = ["-no-reboot"]

[qemu.disk]
size = "2G"
format = "qcow2"
create_options = "lazy_refcounts=on"
hda_options = "cache=writeback"
floppy_a_type = "144"
floppy_b_type = "144"

[qemu.network]
device = "ne2k_isa"
enabled = true
forwards = [[2200, 22], [2300, 23]]

[qemu.display]
backend = "gtk"
acceleration = "tcg"
vga = "cirrus"

[qemu.serial]
auxiliary = "null"
```

Available profiles are `default`, `linux-0.99`, `linux-1.0`, `linux-1.2`,
`linux-2.0-isa`, `linux-2.0`, `linux-2.2`, and `linux-2.4`. If `forwards` is
absent, Python assigns loopback SSH and Telnet forwards from the ranges starting
at ports 2200 and 2300. An explicit empty array disables forwarding.

The stager supplies conventional `boot.img`, `root.img`, `install.iso`, and FAT
media. Do not encode ordinary media attachment in `qemu.extra`.

## Automated Installation

Set `install.driver` to one of:

- `debian-dinstall`
- `slackware-pkgtool`
- `slackware-sysinstall`
- `redhat-perl`
- `redhat-c`
- `redhat-unattended`
- `prompt-sequence`

Family-driver options are grouped into logical tables such as `install.boot`,
`install.disk`, `install.network`, `install.locale`, and an installer-family
table. Leaf names map to the selected driver's option dataclass. See the
existing configs and `hostlib/installers/` for supported fields.

Example Slackware boot configuration:

```toml
[install]
driver = "slackware-pkgtool"

[install.boot]
boot_prompt = "boot:"
root_prompt = "VFS: Insert ramdisk floppy and press ENTER"
continuation_prompt = "VFS: Insert root floppy and press ENTER"
root_image = "root.img"
```

Omit optional prompts when they do not occur. Set `boot_prompt = false` when a
kernel starts without an interactive boot prompt.

Use `prompt-sequence` for exceptional linear installers that cannot share a
family driver:

```toml
[install]
driver = "prompt-sequence"
default_transport = "vga"

[[install.steps]]
action = "wait"
text = "boot:"
match = "line"

[[install.steps]]
action = "type"
text = "ramdisk root=/dev/fd0\n"

[[install.steps]]
action = "change-floppy"
image = "root.img"

[[install.steps]]
action = "prompt"
questions = ["Continue with installation?", "Select (y/n):"]
answer = "y"
```

Supported actions are `wait`, `type`, `press`, `prompt`, `partition`,
`change-floppy`, `set-boot`, `serial-send`, `serial-shell-start`,
`serial-shell-send`, `serial-shell-exit`, `console-echo`, and `run-postinst`.
Use `\n` for Enter and `\t` for Tab in typed text. `${install.table.key}`
interpolates another install value. Set `install.default_transport` to `vga` or
`serial` to choose the transport for `wait` and `prompt` steps that omit it.
An explicit step-level `transport` overrides that default. Without a configured
default, `wait` uses VGA and `prompt` uses serial for compatibility.
`serial-shell-send.command` may be one string or an array of strings; arrays
run in order, waiting for the configured prompt after each command by default.

Keep screen sequences and branching in `hostlib/installers/`. Only truly
exceptional linear sequences belong in distro TOML. Per-distro Python install
scripts are not supported.

## Post-Installation Configuration

`[postinst]` is converted during staging to
`qemu.d/fat/guestlib.d/distro/config.sh`. The guest runner sources that file
and executes `stages` in order. Supported stages are `packages`, `modules`,
`network`, `tty`, `x11`, and `custom`.

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
rules in [guestlib/README.md](guestlib/README.md).

## Slackware Tagsets

Slackware 1.1.2 and later installs may use `*.tag` files. Each line is
`series package state`, where state is `ADD`, `REC`, `OPT`, or `SKP`; `*` sets
the series default. A variant-level tagset shadows the version-level file.

Run `retro tagfile slackware/VERSION/VARIANT` to regenerate `default.tag` from
staged packages. Installer package series and tagfile paths are configured in
`[install.slackware]`.

## Generated Files

Do not edit `qemu.d/`, `download.d/`, `tagfile.d/`, or staged
`qemu.d/fat/guestlib.d/` copies. Edit `config.toml`, `guestlib/`, custom source
scripts, tagsets, and source READMEs instead.

## Validation

Run the cheap checks after source changes:

```bash
git diff --check
python3 -m unittest tests.test_python
tests/shellcheck.sh
black --check .
```

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
