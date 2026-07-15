# Guest Library

`guestlib/` contains portable code that runs in old installer environments and
installed guests. During `retro extract`, the host stages it at
`qemu.d/fat/guestlib.d/` and writes declarative post-install settings to
`guestlib.d/distro/config.sh`. A distro `postinst.sh` is copied only for a
configured custom stage. Host-side install automation mounts that FAT disk at
`/retro` and starts `/retro/guestlib.d/postinst.sh` after installation.

Do not edit staged `qemu.d/fat/guestlib.d/` files; edit this directory or the
distro's source `postinst.sh`. Host staging is implemented and documented in
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
stage names are `modules`, `network`, `tty`, `x11`, and `custom`. The `custom`
stage sources the staged distro `postinst.sh` for exceptional guest logic.

The runner provides these lazy-loading public wrappers:

| Wrapper | Helper | Purpose |
| --- | --- | --- |
| `mod_config` | `config/modules.sh` | Configure kernel module autoloading. |
| `net_config` | `config/net.sh` | Write basic network configuration. |
| `tty_config` | `config/tty.sh` | Enable a serial login console. |
| `x11_config` | `config/x11.sh` | Generate an XFree86 configuration. |

It sets `ETC_D` to `/etc` and defaults `POSTINST_DEBUG` to `0`,
`POSTINST_LOG` to `/postinst.log`, and `POSTINST_REBOOT` to `false`.
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
helpers. A custom distro `postinst.sh` receives any values from
`[postinst.custom]` as uppercase variables and should perform only the
exceptional action that standard stages cannot express. Keep ordinary helper
configuration and stage ordering in TOML. Helper files must remain
function-only so they can be safely sourced.

The runner sets `GUESTLIB_D=/retro/guestlib.d`; manifests may use it to invoke
additional staged scripts. Keep media changes, VGA waits, and keyboard input in
the host-side installer driver or declarative install steps, not in this
manifest.

## Configuration Helpers

### `mod_config`

Set `MOD_ENABLE` to newline-separated `name [options...]` module specs.
The helper detects Slackware (`$ETC_D/rc.d/rc.modules`) and Debian
(`$ETC_D/init.d/modules` or `modutils`) layouts, preserving first backups with
a `~` suffix. It appends module names and options to Debian's `modules` and
`conf.modules`, or `/sbin/modprobe` lines to Slackware's `rc.modules`.

### `net_config`

Set `NET_HOSTNAME`; other defaults target QEMU user networking:
`NET_IPADDR=10.0.2.15`, `NET_NETMASK=255.255.255.0`,
`NET_NETWORK=10.0.2.0`, `NET_BROADCAST=10.0.2.255`,
`NET_GATEWAY=10.0.2.2`, `NET_NAMESERVER=10.0.2.3`, and
`NET_DOMAINNAME=retro.net`. The helper supports Slackware `rc.inet1`, SysV
`init.d/network`, and `rc.net` layouts, retaining first backups with `~`.

Optional settings: `NET_DOMAINNAME` (empty or `none` suppresses domain
records), `NET_ANCIENT_ROUTE=1`, `NET_HOSTNAME_INIT_SET=1`, static ARP values
in `NET_GATEWAY_HWADDR` and `NET_NAMESERVER_HWADDR`, and command overrides
`NET_IFCONFIG_PATH`, `NET_ROUTE_PATH`, and `NET_ARP_PATH`.

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
then `/dev/cua1`; `X11_MOUSETYPE` follows the selected device.

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
Debian, Slackware, and early Red Hat installers. The current Debian and
Slackware automation replaces the real binary with this executable, turning
each curses screen into a labeled text exchange on the control serial port.
The Python `Dialog` driver consumes that exchange and sends the answer expected
by the original installer. Its protocol contract is documented in
[`hostlib/dialog.py`](../hostlib/dialog.py).

For example, a menu exchange is:

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

The labels are a wire protocol, not just diagnostic output. The adapter emits
`BACKTITLE:`, `TITLE:`, `TYPE:`, one `TEXT:` line per prompt line, widget
metadata, `ITEM:` lines, and `RESPONSE:` where input is required. Preserve
their spelling and ordering, including `ITEM: tag :: description` and empty
`TEXT:` lines. The Python Dialog matcher finds `TITLE:` and `TYPE:` in stream
order, may inspect `ITEM:` lines to distinguish similar menus or select by
description, and waits for `RESPONSE:` before answering.

Answers must use the value expected by `dialog`: an item tag for menus, text
for input boxes, and a button word such as `yes`, `no`, `ok`, `cancel`, or
`esc` for button widgets. Empty menu and radiolist answers choose the default
item; an empty checklist answer retains the initially selected items.

Prompt output stays separate from result output. Real `dialog` writes selected
or typed values to stderr unless `--stdout`, `--stderr`, or `--output-fd`
selects another descriptor. Installer scripts redirect that result stream into
files, so protocol text must never leak onto it. Value widgets write their tag
or text to the selected result fd, checklists honor `--separate-output`, and
OK/Yes, Cancel/No, and Esc return statuses 0, 1, and 255 respectively.

Supported widgets are `msgbox`, `infobox`, `yesno`, `inputbox`, `passwordbox`,
`menu`, `inputmenu`, `checklist`, `radiolist`, `textbox`, and `gauge`. The
adapter handles titles, output-fd selection, checklist output, defaults, labels,
positioning, and the cosmetic options used by supported installers. Other long
options are emitted as `OPTION:` metadata and ignored. Gauges emit changed
message text while discarding percentage and `XXX` control lines.

`SERIAL` selects the duplex control device and defaults to `/dev/ttyS3`. When
the device is writable, the adapter reads answers from it, writes prompts to
it, and mirrors the exchange to the console. Otherwise it reads stdin and
writes prompts only to the console. Infoboxes are omitted from serial by
default because they require no answer; set `SERIAL_INFOBOXES=1` to include
them in the host transcript.

Some installers must move an already-running real dialog aside before copying
the adapter into place. On its first invocation, after that process has exited,
the adapter removes `/bin/dialog.bak` or `/usr/bin/dialog.bak` to reclaim scarce
ramdisk space. The `.bak` suffix follows the Slackware replacement convention.

The adapter is a standalone `/bin/sh` executable, not a sourced library. It
must run under Bash 1.14 and ash 0.2 using only shell builtins plus its existing
`rm` dependency. Do not add modern shell syntax or utilities such as `grep`,
`awk`, `sed`, `cat`, `printf`, `mktemp`, or `command -v`. Installer ramdisks
may also have almost no free space, so keep the script compact and avoid
temporary files.
