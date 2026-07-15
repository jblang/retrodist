# Contributing

This guide is the main reference for adding and maintaining distro configs.
The Python commands `retro` and `qmp` are the supported workflow, and
configuration belongs in `config.toml`.

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

## Extraction

`retro extract CONFIG` downloads media, stages it in `qemu.d/`, refreshes the
guest library, and writes `qemu.d/.extracted`.

The standard `[extract]` table supports:

- `source`: an ISO, directory, or downloaded source path.
- `boot_image`, `root_image`, and `extra_images`: files staged at the top of
  `qemu.d/`.
- `fat_files`: files staged in `qemu.d/fat/`.
- `packages`: directory tree staged as `qemu.d/fat/packages/`.
- `decompress`: staged gzip files or glob patterns to decompress.
- `truncate`: staged floppy files or glob patterns to normalize to 1.44 MB.
- `boot_link` and `root_link`: staged source names for `boot.img` and `root.img`.
- `packages_as_install`: rename the staged package directory to `fat/install`.
- `custom_script`: exceptional shell extraction script.

Example:

```toml
[extract]
source = "disc1.iso"
boot_image = "bootdsks.144/bare.i"
root_image = "rootdsks/color.gz"
extra_images = ["rootdsks/text.gz"]
fat_files = ["kernels/bare.i/bzImage"]
packages = "slakware"
decompress = ["*.gz"]
boot_link = "bare.i"
root_link = "color"
```

Use `custom_script = "extract.sh"` only for archive reshaping, image conversion,
or package replacement that the standard stager cannot express. Python runs
that script as a bounded exception and does not parse configuration from it.
Keep all ordinary extraction settings in TOML.

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

[[install.steps]]
action = "wait"
transport = "vga"
text = "boot:"
match = "line"

[[install.steps]]
action = "type"
text = "ramdisk root=/dev/fd0\n"

[[install.steps]]
action = "change-floppy"
image = "root.img"
```

Supported actions are `wait`, `type`, `press`, `prompt`, `partition`,
`change-floppy`, `set-boot`, `serial-send`, `serial-shell-start`,
`serial-shell-send`, `serial-shell-exit`, `console-echo`, and `run-postinst`.
Use `\n` for Enter and `\t` for Tab in typed text. `${install.table.key}`
interpolates another install value.

Keep screen sequences and branching in `hostlib/installers/`. Only truly
exceptional linear sequences belong in distro TOML. Per-distro Python install
scripts are not supported.

## Post-Installation Configuration

`[postinst]` is converted during staging to
`qemu.d/fat/guestlib.d/distro/config.sh`. The guest runner sources that file
and executes `stages` in order. Supported stages are `modules`, `network`,
`tty`, `x11`, and `custom`.

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
domainname = "retro.net"

[postinst.tty]
dev = "ttyS0"
baud = 9600

[postinst.x11]
chipset = "clgd5434"
mouse_device = "/dev/psaux"
```

Use `stages = ["custom"]` with `custom_script = "postinst.sh"` only when the
guest needs logic not expressible through the standard stages. Custom scripts
must follow the portability rules in [guestlib/README.md](guestlib/README.md).

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
tests/unit.sh
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
