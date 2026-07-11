# Guest Library

`guestlib/` contains portable code that runs in old installer environments and
installed guests. During `retro extract`, the host stages it at
`qemu.d/fat/guestlib.d/` and copies the selected distro's `postinst.sh` to
`guestlib.d/distro/`. Host-side install automation mounts that FAT disk at
`/retro` and starts `/retro/guestlib.d/postinst.sh` after installation.

Do not edit staged `qemu.d/fat/guestlib.d/` files; edit this directory or the
distro's source `postinst.sh`. Host staging details are in
[hostlib/README.md](../hostlib/README.md); adding a distro is covered by
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

`postinst.sh` expects `/retro/guestlib.d` to be mounted, loads logging, and
sources `/retro/guestlib.d/distro/postinst.sh`. It provides these lazy-loading
public wrappers for manifests:

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

Each distro `postinst.sh` should set only the variables it needs and call the
appropriate wrappers. Helper files must remain function-only so they can be
safely sourced.

A normal manifest is intentionally small:

```sh
MOD_ENABLE="tulip"
mod_config

NET_HOSTNAME=darkstar
net_config

tty_config
x11_config
```

The runner sets `GUESTLIB_D=/retro/guestlib.d`; manifests may use it to invoke
additional staged scripts. Keep media changes, VGA waits, and keyboard input in
the host-side `install.sh`, not in this manifest.

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

`logging.sh` writes plain messages to stderr and `$POSTINST_LOG`. Use
`log LEVEL MESSAGE...`; `DEBUG` requires `POSTINST_DEBUG=1`. Every level is
prefixed with `LEVEL:` except `INFO`, which has no prefix. `log_div` writes a
divider, and `die MESSAGE...` logs an error then exits.

`dialog.sh` is a serial plain-text adapter used during installation by the
shared Debian and Slackware drivers. It does not run the real `dialog` binary,
but preserves redirected result files expected by installer scripts. Set
`DIALOG_SERIAL_INFOBOXES=1` to include infoboxes in the serial transcript. The
host-side protocol is documented under
[Dialog Installers](../hostlib/README.md#dialog-installers).
