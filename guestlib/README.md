# Guest Library

`guestlib/` contains portable code that runs in old installer environments and
installed guests. During `retro extract`, the host stages it at
`qemu.d/fat/guestlib.d/` and writes declarative post-install settings to
`guestlib.d/distro/config.sh`. A distro `postinst.sh` is copied only for a
configured custom stage. Host-side install automation mounts that FAT disk at
`/retro` and starts `/retro/guestlib.d/postinst.sh` after installation.

Do not edit staged `qemu.d/fat/guestlib.d/` files; edit this directory or the
distro's source `postinst.sh`. Host staging is implemented in
[`hostlib/guestlib.py`](../hostlib/guestlib.py) and coordinated by
[`hostlib/media.py`](../hostlib/media.py); adding a distro is covered by
[CONTRIBUTING.md](../CONTRIBUTING.md).

## Compatibility

- Use portable `sh`; these scripts run on very old installer and target systems.
- Do not use `if ! command; then`: old Bash and ash handle command negation
  incorrectly. `[ ! -f file ]` is safe.
- Installer-facing scripts may lack `grep`, `awk`, `which`, and `command -v`.
  Post-installation helpers can use installed tools, but not modern options.
- Keep staged names and paths DOS-friendly because some installers use an
  `msdos` mount.

## Post-Installation Runner

`postinst.sh` expects `/retro/guestlib.d` to be mounted and loads logging. Host
staging writes `/retro/guestlib.d/distro/config.sh`; the runner sources that
generated file and executes its `POSTINST_STAGES` in order. Supported
stage names are `packages`, `modules`, `network`, `tty`, `x11`, and `custom`.
The `packages` stage sources the host-generated `distro/packages.sh`; the
`custom` stage sources the staged distro `postinst.sh` for exceptional guest
logic.

For Debian package configuration prompts, the installer runs the post-install
stage on its automation serial port. Configure every question and answer under
`[[postinst.packages.prompts]]`; questions may arrive in any order, and an
empty answer submits Enter.

The runner provides these lazy-loading public wrappers:

| Wrapper | Helper | Purpose |
| --- | --- | --- |
| `mod_config` | `config/modules.sh` | Configure kernel module autoloading. |
| `net_config` | `config/net.sh` | Write basic network configuration. |
| `tty_config` | `config/tty.sh` | Enable a serial login console. |
| `x11_config` | `config/x11.sh` | Generate an XFree86 configuration. |

The runner defines these defaults:

| Variable | Default | Purpose |
| --- | --- | --- |
| `ETC_D` | `/etc` | Root of the guest's configuration files. |
| `POSTINST_DEBUG` | `0` | Enables debug logging when set to `1`. |
| `POSTINST_LOG` | `/postinst.log` | Receives post-install log messages. |
| `POSTINST_REBOOT` | `false` | Controls whether the guest reboots after the stages finish. |

`mod_config`, `net_config`, and `tty_config` set `POSTINST_REBOOT=true` when
called; `x11_config` does not. The runner syncs and reboots for `true`, `TRUE`,
`True`, `yes`, `YES`, `Yes`, or `1`.

Normal configuration belongs in the distro's `config.toml`:

```toml
[postinst]
stages = ["modules", "network", "tty", "x11"]

[postinst.modules]
enable = "tulip"

[postinst.network]
hostname = "darkstar"
```

Python converts these keys to the uppercase variables used by the portable
helpers; canonical `domain` and `ip` become `NET_DOMAINNAME` and `NET_IPADDR`.
A custom distro `postinst.sh` receives any values from
`[postinst.custom]` as uppercase variables and should perform only the
exceptional action that standard stages cannot express. Keep ordinary helper
configuration and stage ordering in TOML. Helper files must remain
function-only so they can be safely sourced.

The runner sets `GUESTLIB_D=/retro/guestlib.d`; manifests may use it to invoke
additional staged scripts. Keep media changes, VGA waits, and keyboard input in
the host-side Python installer driver, not in this manifest.

## Configuration Helpers

### `mod_config`

Set `MOD_ENABLE` to newline-separated `name [options...]` module specs.
The helper detects Slackware (`$ETC_D/rc.d/rc.modules`) and Debian
(`$ETC_D/init.d/modules` or `modutils`) layouts, preserving first backups with
a `~` suffix. It appends module names and options to Debian's `modules` and
`conf.modules`, or `/sbin/modprobe` lines to Slackware's `rc.modules`.

### `net_config`

Set `NET_HOSTNAME`. The remaining defaults target QEMU user networking:

| Variable | Default |
| --- | --- |
| `NET_IPADDR` | `10.0.2.15` |
| `NET_NETMASK` | `255.255.255.0` |
| `NET_NETWORK` | `10.0.2.0` |
| `NET_BROADCAST` | `10.0.2.255` |
| `NET_GATEWAY` | `10.0.2.2` |
| `NET_NAMESERVER` | `10.0.2.3` |
| `NET_DOMAINNAME` | `retro.net` |

Optional settings provide compatibility with older network layouts:

| Setting | Effect |
| --- | --- |
| Empty `NET_DOMAINNAME`, or `none` | Suppresses domain records. |
| `NET_ANCIENT_ROUTE=1` | Uses routing syntax needed by ancient guests. |
| `NET_HOSTNAME_INIT_SET=1` | Adds `hostname -S` to the generated init script. |
| `NET_GATEWAY_HWADDR`, `NET_NAMESERVER_HWADDR` | Add static ARP entries. |
| `NET_IFCONFIG_PATH`, `NET_ROUTE_PATH`, `NET_ARP_PATH` | Override command paths. |

The helper supports Slackware `rc.inet1`, SysV `init.d/network`, and `rc.net`
layouts. It retains the first backup of each changed file with a `~` suffix.

### `tty_config`

Enables a serial getty using `TTY_DEV` (default `ttyS0`), `TTY_BAUD` (default
`9600`), `TTY_ID`, and `TTY_RUNLEVELS` (default `123456`). It recognizes old
`ttysN` spellings, preserves `.orig` backups, leaves an existing active getty
alone, and requires a commented stock serial getty line. It also updates
`login.defs` and `securetty` when present.

### `x11_config`

Detects XFree86 4.x, 3.x SVGA, 1.x/2.x SVGA, or X386 monochrome servers and
writes the corresponding `XF86Config` or `Xconfig`. Existing configuration is
saved as `.orig`. `X11_MOUSEDEV` defaults through `/dev/psaux`, `/dev/ps2aux`,
then `/dev/cua1`; serial `/dev/cua*` and `/dev/ttyS*` devices use the
Microsoft protocol automatically.

For color configurations, `X11_DEPTHS` defaults to `16 8 32` and `X11_MODES`
to `"1024x768" "800x600" "640x480"`. `X11_CHIPSET` defaults to `clgd5434`;
the monochrome fallback uses only `"640x480"` unless overridden.

These helpers detect several historical file layouts because that compatibility
is their purpose. Add a new layout only when a represented guest requires it;
keep release-specific exceptions in the distro manifest when they do not form
a reusable family.

## Shared Utilities

### `logging.sh`

`logging.sh` writes plain messages to stderr and `$POSTINST_LOG`. Use
`log LEVEL MESSAGE...`; `DEBUG` requires `POSTINST_DEBUG=1`. Every level is
prefixed with `LEVEL:` except `INFO`, which has no prefix. `log_div` writes a
divider, and `die MESSAGE...` logs an error then exits.

### `dialog.sh`

`dialog.sh` is a plain-text replacement for
[dialog(1)](https://linux.die.net/man/1/dialog), whose interface appears in the
Debian, Slackware, and early Red Hat installers. Their automation replaces an
installer's real binary with this shell script, turning widgets that use the stub
into labeled text exchanges on the control serial port. Other screens may
remain VGA-driven. The Python `Dialog` driver consumes each exchange and sends
the answer expected by the original installer. Its protocol contract is
documented in
[`hostlib/install/dialog.py`](../hostlib/install/dialog.py).

#### Protocol Example

A menu exchange looks like this:

```text
--------------------------------------------------------------------------------
TITLE: Select Keyboard
TYPE: menu
TEXT: Select a keyboard layout.
SIZE: 12 50
MENUHEIGHT: 4
ITEM: us :: U.S. English
ITEM: uk :: United Kingdom
RESPONSE: us
```

The labels form a wire protocol, not merely diagnostic output. The adapter
emits fields in this order:

1. `BACKTITLE:` and `TITLE:`, when configured.
2. `TYPE:` with the widget type.
3. One `TEXT:` field for each prompt line.
4. Widget-specific metadata and `ITEM:` fields.
5. `RESPONSE:` when the widget requires input.

Preserve field spelling and ordering. In particular:

- Keep empty `TEXT:` lines.
- Format choices as `ITEM: tag :: description`.
- Do not rename or rearrange protocol fields.

The Python matcher finds `TITLE:` and `TYPE:` in stream order. It may inspect
`TEXT:` and `ITEM:` fields to distinguish similar widgets or select an item by
description. It waits for `RESPONSE:` before sending an answer.

#### Answers and Defaults

Answers use the values expected by the real `dialog` program:

| Widget kind | Answer |
| --- | --- |
| Menu, input menu, or radiolist | The selected item's tag. |
| Checklist | One or more item tags. |
| Input box | The entered text. |
| Button widget | `yes`, `no`, `ok`, `cancel`, or `esc`. |

Empty answers have widget-specific meanings:

- For a menu or radiolist, select the default item.
- For a checklist, retain the initially selected items.

#### Output and Exit Status

Prompt output must remain separate from result output. Installer scripts often
redirect the result stream into files, so protocol text must never leak onto
that stream.

By default, real `dialog` writes selected or typed values to stderr. The
`--stdout`, `--stderr`, and `--output-fd` options can select another descriptor.
Value widgets write their tag or text to that descriptor, and checklists honor
`--separate-output`.

| Result | Exit status |
| --- | ---: |
| OK or Yes | `0` |
| Cancel or No | `1` |
| Esc | `255` |

#### Widgets and Options

The adapter supports these widgets:

- Messages: `msgbox`, `infobox`, `textbox`
- Buttons and text entry: `yesno`, `inputbox`, `passwordbox`
- Choices: `menu`, `inputmenu`, `checklist`, `radiolist`
- Progress: `gauge`

It handles titles, output descriptor selection, checklist output, defaults,
labels, positioning, and the cosmetic options used by supported installers.
Other long options are emitted as `OPTION:` metadata and ignored.

When gauges are enabled for serial output, they emit changed message text and
discard percentages and `XXX` control lines.

#### Serial Behavior

`SERIAL` selects the duplex control device and defaults to `/dev/ttyS3`.
Behavior depends on whether that device is writable:

| Serial device | Answers read from | Prompts written to |
| --- | --- | --- |
| Writable | Serial device | Serial device and console |
| Not writable | stdin | Console only |

Infoboxes and gauges are omitted from serial output by default because they do
not require an answer. Set `SERIAL_INFOBOXES=1` to include them in the host
transcript.

#### Replacement Cleanup

Some installers must move an already-running real dialog aside before copying
the adapter into place. On its first invocation, after that process has exited,
the adapter removes `/bin/dialog.bak` or `/usr/bin/dialog.bak` to reclaim scarce
ramdisk space.

#### Portability Constraints

The adapter is a standalone `/bin/sh` executable, not a sourced library. It
must run under Bash 1.14 and ash 0.2 using only shell builtins plus its existing
`rm` dependency.

- Do not add modern shell syntax.
- Do not add utilities such as `grep`, `awk`, `sed`, `cat`, `printf`, `mktemp`,
  or `command -v`.
- Keep the script compact and avoid temporary files. Installer ramdisks may
  have almost no free space.
