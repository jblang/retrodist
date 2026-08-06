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

Unknown keys inside a supported table and incorrectly typed values are errors.
Only the top-level tables listed below are consumed. When adding a new setting,
update its Python model or validator and add unit coverage.

The supported top-level tables are:

| Table | Used by | Required for |
| --- | --- | --- |
| `[download]` | `retro download` and the extraction prerequisite | Any media that is not already local. |
| `[extract]` | `retro extract`, `boot`, and `install` | `retro extract`; it may contain only a custom hook when no source selection is needed. |
| `[qemu]` | `retro boot` and `retro install` | Booting or installing a VM. |
| `[install]` | `retro install` | Automated installation. Omit it for boot-only configs. |
| `[postinst]` | Extraction and supported installer drivers | Optional installed-system configuration. |

Reference tables below use these conventions: `string[]` means an array of
strings, `[[table]]` means an array of tables, and *none* means that the key is
omitted unless the config supplies it. TOML has no null value; omit optional
settings instead. Defaults are applied after parent/child inheritance. All
models are strict: for example, `"true"` is not accepted where a Boolean is
required, and a scalar is not accepted in place of an array.

## Downloads

`retro download CONFIG` supports these `[download]` settings. Every key is
optional and more than one source form may be combined.

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cdrom` | string | none | Config name below `cdrom/`. The referenced config is downloaded and its top-level ISO files are linked into the selected config's `qemu.d/`. |
| `slackware_mirror` | string | none | Version directory from the official Slackware mirror, such as `1.01`. |
| `debian_mirror` | string | none | Archived Debian release name, such as `buzz`; downloads the release files and directories recognized by the downloader. |
| `files` | `[[download.files]]` | `[]` | Direct downloads, each described by the required keys below. |

| `download.files` setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `path` | string | required | Relative destination beneath the effective download directory. |
| `url` | string | required | URL passed to `wget`. |

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

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `source` | string | `""` | ISO, tar, 7-Zip, or ZIP archive, directory, or downloaded source path. The file type selects the extraction implementation. |
| `boot_image` | string | none | Boot image selected from `source`, staged at the top of `qemu.d/`, and used as the default target of `boot.img`. |
| `root_image` | string | none | Root image selected from `source`, staged at the top of `qemu.d/`, and used as the default target of `root.img`. |
| `extra_images` | string[] | `[]` | Additional disk images or image glob patterns selected from `source` and staged at the top of `qemu.d/`. |
| `files` | string[] | `[]` | Other files or glob patterns selected from `source` and staged at the top of `qemu.d/`. |
| `fat_files` | string[] | `[]` | Files or glob patterns selected from `source` and staged in `qemu.d/fat/`. |
| `package_source` | string | none | One package directory tree selected from `source` and copied below `package_dest`. |
| `package_sources` | string[] | `[]` | Package directory trees merged below `package_dest`, for media split into trees such as `binary-i386` and `binary-all`. Mutually exclusive with `package_source`. |
| `package_index` | string | none | Debian `Packages` or `Packages.gz` index selected from `source`, staged at the top of `qemu.d/`, and parsed when generating the post-install package script. |
| `package_dest` | string | `"packages"` | Package-tree destination beneath `qemu.d/fat/`. |
| `decompress` | string[] | `[]` | Names or glob patterns for staged gzip files to decompress; matching `.gz` files are replaced by their uncompressed forms. |
| `truncate` | string[] | `[]` | Names or glob patterns for staged, uncompressed floppy images to truncate to 1.44 MB. |
| `boot_link` | string | none | Staged filename to link as `boot.img`, overriding the basename of `boot_image`. |
| `root_link` | string | none | Staged filename to link as `root.img`, overriding the basename of `root_image`. |
| `custom_script` | string | none | Exceptional Bash hook run after source selection and before overlays, links, decompression, and truncation. |
| `overlays` | `[[extract.overlays]]` | `[]` | File replacements applied after the custom hook. Each entry has the required keys below. |

| `extract.overlays` setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `source` | string | required | Source file. Relative paths start in the effective download directory; absolute paths are accepted. |
| `destination` | string | required | Relative destination beneath `qemu.d/`; parent traversal is rejected. |

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

### QEMU setting reference

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `qemu.profile` | string enum | `"default"` | Hardware profile from the table below. |
| `qemu.disk.size` | string | profile value | Size passed to `qemu-img create`, such as `"500M"` or `"2G"`. It affects creation of a missing `hda.img`, not an existing disk. |
| `qemu.network.device` | string | profile value | QEMU NIC device name, such as `"ne2k_isa"`, `"pcnet"`, or `"tulip"`. |
| `qemu.network.enabled` | Boolean | `true` | When false, omit both the user-mode network backend and guest NIC. |
| `qemu.network.forwards` | array of two-integer arrays | automatic | Each pair is `[host_port, guest_port]`. Omit for automatic SSH and Telnet forwards; use `[]` for no forwards. |
| `qemu.serial.auxiliary` | string | `"null"` | Backend for guest `ttyS2`, passed as a QEMU `-serial` value. An empty string omits `ttyS2`; `ttyS0`, `ttyS1`, and automation port `ttyS3` are fixed project endpoints. |

Profile values are deliberately centralized rather than repeated in distro
configs:

| Profile | Machine | RAM | Disk | NIC | VGA |
| --- | --- | ---: | ---: | --- | --- |
| `default` | ISA PC | 16 MB | 500 MB | `ne2k_isa` | QEMU default |
| `linux-0.99` | ISA PC | 64 MB | 500 MB | `ne2k_isa` | QEMU default |
| `linux-1.0` | ISA PC | 64 MB | 512 MB | `ne2k_isa` | QEMU default |
| `linux-1.2` | ISA PC | 64 MB | 2 GB | `ne2k_isa` | QEMU default |
| `linux-2.0-isa` | ISA PC | 64 MB | 2 GB | `ne2k_isa` | QEMU default |
| `linux-2.0` | PCI PC | 64 MB | 8 GB | `tulip` | `cirrus` |
| `linux-2.2` | PCI PC | 64 MB | 8 GB | `tulip` | `cirrus` |
| `linux-2.4` | PCI PC | 128 MB | 8 GB | `tulip` | `std` |

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
screen sequences, boot prompts, and installer quirks. Use a release range or
descriptive name when several releases share the same profile.

### Installer setting reference

The driver determines which nested tables are legal. The applicability column
uses the exact `install.driver` values; a setting supplied to any other driver
is rejected.

| Setting | Type | Default | Applies to / meaning |
| --- | --- | --- | --- |
| `install.driver` | string enum | required | Selects one driver from the table above. |
| `install.variant` | string enum | required | Required by `debian-dialog`, `slackware-dialog`, `redhat-dialog`, and `redhat-newt`; accepted values are in the driver table above. Not accepted by the focused drivers. |

Every driver accepts `[install.disk]`:

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `target_disk` | string | `"/dev/hda"` | Whole target disk passed to partitioning steps. |
| `swap_mb` | integer | QEMU profile RAM in MB | Requested swap size. The schema fallback is 64, but a resolved config with `[qemu]` derives this value from the selected profile unless explicitly set. |
| `swap_partition` | string | `"/dev/hda1"` | Swap partition used by the installer. |
| `root_partition` | string | `"/dev/hda2"` | Root partition used by the installer. |
| `fat_partition` | string | `"/dev/hdb1"` | Partition exposing the staged FAT exchange disk. |
| `fat_mount` | string | `"/retro"` | Guest mount point for the FAT exchange disk. |
| `fat_filesystem` | string | `"msdos"` | Filesystem name used when mounting the exchange disk during installation. |

`[install.locale]` is accepted by `debian-dialog`, `debian-091`,
`slackware-dialog`, `slackware-tty`, `redhat-dialog`, and `redhat-newt`:

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `hardware_clock` | `"utc"` or `"local"` | `"utc"` | Whether the hardware clock is interpreted as UTC or local time. |
| `keymap` | string | `"us"` | Installer keymap selection. `redhat-dialog` defaults to `"us.map"`. |
| `timezone` | string | `"UTC"` | Installer timezone selection. `debian-dialog` defaults to `"Etc/UTC"`; `debian-091` defaults to `"US/Central"`. |

`[install.network]` is accepted by `debian-dialog`, `debian-091`,
`slackware-dialog`, `slackware-tty`, `redhat-dialog`, and `redhat-newt`:

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `hostname` | string | driver-specific | Guest hostname: `"debian"` for `debian-dialog`, `"debra"` for `debian-091`, `"darkstar"` for Slackware, and `"redhat"` for Red Hat. |
| `domain` | string | `"retro.net"` | DNS domain. |
| `ip` | string | `"10.0.2.15"` | Static guest IPv4 address. |
| `netmask` | string | `"255.255.255.0"` | Static IPv4 netmask. |
| `network` | string | `"10.0.2.0"` | Static network address. |
| `broadcast` | string | `"10.0.2.255"` | Static broadcast address. |
| `gateway` | string | `"10.0.2.2"` | Default gateway under QEMU user networking. |
| `nameserver` | string | `"10.0.2.3"` | DNS resolver under QEMU user networking. |
| `net_module` | string | none | `debian-dialog` only: installer network module to load. |
| `net_module_args` | string | `""` | `debian-dialog` only: arguments supplied to `net_module`. |

`[install.prompts]` is accepted by `slackware-dialog`, `redhat-dialog`, and
`redhat-newt`:

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `boot_prompt` | string | `"boot:"` | Text awaited before sending `boot_command`. |
| `boot_command` | string | `""` | Input sent at the boot prompt. |
| `boot_sleep` | number | `0` | Seconds to pause during the driver's boot sequence. |
| `postinst_prompt` | string | none | Screen prompt awaited before starting configured post-install work. |

The remaining tables are driver-specific:

| Driver and table | Setting | Type | Default | Meaning |
| --- | --- | --- | --- | --- |
| `debian-dialog` `[install.boot]` | `prompt` | string | `"boot:"` | Initial boot prompt. |
| | `command` | string | `""` | Initial boot command. |
| | `root_prompt` | string | none | Optional prompt for exchanging the root floppy. |
| | `root_image` | string | `"root.img"` | Staged root-floppy filename used at that prompt. |
| `debian-dialog` `[install.accounts]` | `root_password` | string | `"password1"` | Root password entered by Dinstall. |
| | `user` | string | `"debian"` | Regular account name. |
| | `user_password` | string | `"password1"` | Regular account password. |
| `slackware-dialog` `[install.packages]` | `source` | string | `"/dev/hdc"` | Setup package source device or path. |
| | `tagfile_path` | string or `false` | `"/retro/tagfiles"` | Custom tagfile path; `false` selects the installer's default tagfiles. |
| | `package_sets` | string | `"\"A\" \"AP\" \"N\" \"X\" \"XAP\""` | Setup-formatted package-series selection. |
| `slackware-dialog` `[install.bootloader]` | `framebuffer` | string | `"standard"` | Framebuffer choice given to LILO setup. |
| | `label` | string | `"linux"` | Installed kernel boot label. |
| `slackware-dialog` `[install.modem]` | `speed` | string | `"38400"` | Modem/serial speed selection. |
| `slackware-dialog` `[install.mail]` | `mode` | string | `"SMTP"` | Mail configuration mode. |
| `slackware-tty` `[install.packages]` | `package_sets` | string | `"A AP D E F IV N TCL OI OOP X XAP XD XV Y"` | Space-separated package series selected by the early tty setup program. |
| `redhat-dialog` `[install.packages]` | `package_series` | string[] | required | Package series selected in the early dialog installer. An empty array is valid. |
| `redhat-dialog` `[install.accounts]` | `root_password` | string | `""` | Root password. |
| | `user` | string | none | Optional user name, from one to eight characters. |
| | `user_home` | Boolean | `true` | Whether the optional user receives a home directory. |
| `redhat-newt` `[install.packages]` | `components` | string[] | required | Newt installer component labels to select. |
| `redhat-newt` `[install.accounts]` | `root_password` | string | `"password"` | Required root credential entered by the driver. |
| `redhat-unattended` `[install.boot]` | `prompt` | string | `"boot:"` | Initial boot prompt. |
| | `command` | string | required | Boot input, such as a Kickstart command. |
| `redhat-unattended` `[install.completion]` | `prompt` | string | required | Text indicating that unattended installation is complete. |
| | `reboot` | Boolean | `true` | Whether to reboot after the completion prompt. |
| | `postinst` | Boolean | `false` | Whether to run configured post-install stages after unattended installation. |
| | `boot_device` | string | `"c"` | QEMU monitor boot-device key used for the installed system. |
| `redhat-unattended` `[install.accounts]` | `root_password` | string | none | Optional root password used by the unattended lifecycle. |
| `redhat-unattended` `[install.prompts]` | `login_prompt` | string | `"login:"` | Installed-system login prompt awaited before post-install work. |
| | `shell_prompt` | string | `"#"` | Root shell prompt awaited during post-install work. |

`slackware-sysinstall` has no driver-specific settings beyond `[install.disk]`.
`debian-091` accepts only `[install.disk]`, `[install.locale]`, and
`[install.network]`. `slackware-tty` accepts those three tables plus its
`[install.packages]` table.

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

Stages run in the declared order. The complete top-level reference is:

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `postinst.stages` | stage-name array | `[]` | Ordered stages from the table above. Repetition is accepted and executes a stage again. |
| `postinst.fat_filesystem` | string | none | Overrides `install.disk.fat_filesystem` when the installed system mounts the exchange disk to start the runner. |
| `postinst.custom_script` | string | none | Guest script resolved from the selected config or immediate parent and staged as `distro/postinst.sh`. Required when `custom` is in `stages`. |
| `postinst.debug` | Boolean | guest default (`false`) | Enables debug logging. |
| `postinst.log` | string | guest default (`"/postinst.log"`) | Guest log path. An empty string disables file logging. |
| `postinst.reboot` | Boolean | guest default (`false`) | Requests a final reboot. The `modules`, `network`, and `tty` wrappers set the reboot flag even when this is false. |
| `postinst.modules` | scalar-value table | `{}` | Settings rendered with a `MOD_` prefix for the `modules` stage. |
| `postinst.network` | table | guest defaults below | Typed static-network and compatibility settings listed below. |
| `postinst.packages` | table | see below | Debian package selection and media settings. |
| `postinst.tty` | scalar-value table | `{}` | Settings rendered with a `TTY_` prefix for the `tty` stage. |
| `postinst.x11` | scalar-value table | `{}` | Settings rendered with an `X11_` prefix for the `x11` stage; `mouse_device` is specially rendered as `X11_MOUSEDEV`. |
| `postinst.custom` | scalar-value table | `{}` | Variables for the custom script, rendered as uppercase names without a prefix. |

The free-form stage tables accept only string, integer, or Boolean values.
These are the settings consumed by the standard helpers:

| Table and setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `postinst.modules.enable` | string | empty | Newline-separated `module [options...]` specifications to enable at boot. |
| `postinst.tty.dev` | string | `"ttyS0"` | Serial device name. Old `ttysN` spelling is recognized. |
| `postinst.tty.baud` | string or integer | `9600` | Getty baud rate. |
| `postinst.tty.id` | string | derived | Inittab identifier, derived from the serial device when omitted. |
| `postinst.tty.runlevels` | string or integer | `123456` | Inittab runlevels for the getty. Quote this value if leading zeroes matter. |
| `postinst.x11.chipset` | string | `"clgd5434"` | Chipset written to applicable XFree86 configurations. |
| `postinst.x11.mouse_device` | string | detected | Mouse device; tries `/dev/psaux`, `/dev/ps2aux`, then `/dev/cua1`. |
| `postinst.x11.mousetype` | string | derived | XFree86 mouse protocol; derived as `PS/2` or `Microsoft` for known device names. |
| `postinst.x11.depths` | string | `"16 8 32"` | Ordered color-depth list for XFree86 3.x/4.x; the first becomes the default. |
| `postinst.x11.modes` | string | server-specific | Quoted, space-separated mode names. Color defaults to `\"1024x768\" \"800x600\" \"640x480\"`; monochrome defaults to `\"640x480\"`. |

Other keys in `[postinst.modules]`, `[postinst.tty]`, and `[postinst.x11]` are
also rendered, but have no effect unless a custom or future guest helper reads
the resulting variable. Prefer the standard names above. Keys in
`[postinst.custom]` are intentionally script-defined; for example,
`archive_path = "/mnt/a.tgz"` becomes `ARCHIVE_PATH='/mnt/a.tgz'`.
Use only letters, digits, and underscores in free-form keys; generated shell
variable names must begin with a letter.

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

`[postinst.packages]` accepts:

| Setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `roots` | non-empty string[] | `["/retro/packages"]` | Ordered guest package-tree roots searched for every selected archive. |
| `priorities` | string[] | `[]` | Debian priorities selected globally, case-insensitively. |
| `add` | string[] | `[]` | Additional package names selected explicitly, case-insensitively. |
| `skip` | string[] | `[]` | Package names excluded even when selected or required as dependencies. |
| `sections` | table of string arrays | `{}` | Per-section priority arrays, replacing `priorities` for the named section. Keys are section names. |
| `prompts` | `[[postinst.packages.prompts]]` | `[]` | Interactive package-configuration exchanges described below. |
| `mount` | `[postinst.packages.mount]` | none | Optional package-media mount performed by the generated installer. |

| Prompt setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `expect` | string | required | Expected prompt text or regular expression. |
| `answer` | string | required | Answer to send; `""` sends Enter. |
| `regex` | Boolean | `false` | Interpret `expect` as a regular expression. |

| Mount setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `device` | string | required | Guest block device containing package media. |
| `point` | string | `"/cdrom"` | Guest mount point. |
| `filesystem` | string | `"iso9660"` | Filesystem passed to `mount -t`. |
| `options` | string | none | Optional value passed to `mount -o`. |

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
guestlib compatibility controls below. Only explicitly supplied values are
rendered. The guest helper supplies QEMU-friendly defaults for all canonical
values except `hostname`, so set `hostname` whenever the `network` stage is
enabled.

| Canonical setting | Type | Guest default |
| --- | --- | --- |
| `hostname` | string | none; set explicitly |
| `domain` | string | `"retro.net"` |
| `ip` | string | `"10.0.2.15"` |
| `netmask` | string | `"255.255.255.0"` |
| `network` | string | `"10.0.2.0"` |
| `broadcast` | string | `"10.0.2.255"` |
| `gateway` | string | `"10.0.2.2"` |
| `nameserver` | string | `"10.0.2.3"` |

| Compatibility setting | Type | Default | Meaning |
| --- | --- | --- | --- |
| `ancient_route` | integer or Boolean | none | Compared literally with `1`; use integer `1` to enable routing syntax required by ancient guests. |
| `hostname_init_set` | integer or Boolean | none | Compared literally with `1`; use integer `1` to add `hostname -S` to the generated init script. |
| `gateway_hwaddr` | string | none | Static ARP address for the gateway. |
| `nameserver_hwaddr` | string | none | Static ARP address for the nameserver. |
| `ifconfig_path` | string | none | Override the guest `ifconfig` command path. |
| `route_path` | string | none | Override the guest `route` command path. |
| `arp_path` | string | none | Override the guest `arp` command path. |

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
