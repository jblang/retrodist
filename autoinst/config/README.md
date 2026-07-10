# Autoinstall Configuration Helpers

These scripts run from `autoconf.sh` during first boot. They are copied to
`autoinst.d/config/` and loaded through wrappers in `autoinst.d/common.sh`.

See [../README.md](../README.md) for portability rules. These files run on old
installed systems, not modern shells.

## `modules.sh`

Wrapper: `mod_config`

Configures module autoloading.

- Detects Slackware via `$ETCPATH/rc.d/rc.modules`.
- Detects Debian via `$ETCPATH/init.d/modules` or
  `$ETCPATH/init.d/modutils`.
- Returns without error when no supported module layout is found.
- Backs up files before the first edit.

Variables:

- `MOD_ENABLE`: newline-separated module specs, one per line:
  `name [options...]`.

Behavior:

- Debian appends module names to `$ETCPATH/modules` and option lines to
  `$ETCPATH/conf.modules`.
- Slackware appends `/sbin/modprobe name [opts]` to
  `$ETCPATH/rc.d/rc.modules`.

## `net.sh`

Wrapper: `net_config`

Writes basic network config for Debian, Slackware, and SLS layouts. Kernel
module loading is separate; use `MOD_ENABLE` and `mod_config`.

Defaults target QEMU user networking:

- `NET_IPADDR`: set by the distro manifest.
- `NET_HOSTNAME`: set by the distro manifest.
- `NET_NETMASK=255.255.255.0`
- `NET_NETWORK=10.0.2.0`
- `NET_BROADCAST=10.0.2.255`
- `NET_GATEWAY=10.0.2.2`
- `NET_NAMESERVER=10.0.2.3`
- `NET_DOMAINNAME=retro.net`

Detection:

- Hostname file: `$ETCPATH/HOSTNAME`, then `$ETCPATH/hostname`.
- Startup script: `$ETCPATH/rc.d/rc.inet1`, then
  `$ETCPATH/init.d/network`, then `$ETCPATH/rc.net`.
- Command paths: honors `NET_IFCONFIG_PATH`, `NET_ROUTE_PATH`, and
  `NET_ARP_PATH` when set; otherwise probes old common paths and falls back to
  unqualified command names.

Variables:

- `NET_DOMAINNAME`: set empty or `none` to skip domain/search records.
- `NET_ANCIENT_ROUTE=1`: use old `route` syntax and skip `/etc/networks`.
- `NET_HOSTNAME_INIT_SET=1`: run `hostname -S` in the generated init script.
- `NET_GATEWAY_HWADDR`: static ARP address for `$NET_GATEWAY`.
- `NET_NAMESERVER_HWADDR`: static ARP address for `$NET_NAMESERVER`.
- `NET_IFCONFIG_PATH`, `NET_ROUTE_PATH`, `NET_ARP_PATH`: command paths used in
  generated scripts.

Backups use a `~` suffix and are not refreshed on later runs.

## `x11.sh`

Wrapper: `x11_config`

Generates XFree86 config for QEMU-style Cirrus/VESA graphics and a basic mouse.

Server preference:

1. `/usr/X11R6/bin/XFree86`
2. `/usr/X11R6/bin/XF86_SVGA`
3. `/usr/X386/bin/XF86_SVGA`
4. `/usr/X386/bin/X386mono`

Supported layouts:

- XFree86 4.x: writes `XF86Config` with the `vesa` driver.
- XFree86 3.x under X11R6: writes `XF86Config` for the `svga` server.
- XFree86 1.x/2.x under `/usr/X386`: writes `Xconfig`, links the selected
  server as `X`, and wraps `startx` to restore the console font when possible.
- X386 mono: writes old `Xconfig` format and selects `VGA2`.

Variables:

- `X11_MOUSEDEV`: defaults to `/dev/psaux`, then `/dev/ps2aux`, then
  `/dev/cua1`.
- `X11_MOUSETYPE`: defaults to `PS/2` for PS/2 devices and `Microsoft` for
  `/dev/cua1`.
- `X11_DEPTHS`: display depths in preference order. Default: `16 8 32`.
- `X11_MODES`: quoted mode list. Default:
  `"1024x768" "800x600" "640x480"`; mono defaults to `"640x480"`.
- `X11_CHIPSET`: Cirrus chipset for SVGA configs. Default: `clgd5229`.

Existing `XF86Config` or `Xconfig` files are saved as `.orig`.

## `tty.sh`

Wrapper: `tty_config`

Enables a serial login console by editing `$ETCPATH/inittab`.

Variables:

- `TTY_DEV`: serial device. Default: `ttyS0`.
- `TTY_BAUD`: baud rate. Default: `9600`.
- `TTY_ID`: inittab id. Defaults from the device suffix.
- `TTY_RUNLEVELS`: default `123456`.

Behavior:

- Does nothing when `$ETCPATH/inittab` is missing.
- Treats `ttyS` and older `ttys` spellings as equivalent.
- Leaves an existing active getty line alone.
- Requires a commented stock serial getty line for `ttyS0`, `ttyS1`, `ttys0`,
  or `ttys1`; without one it logs a warning.
- Comments out `CONSOLE` in `login.defs` so `securetty` controls root login.
- Adds the serial TTY to `securetty` when needed.
- Saves first backups as `.orig`.

Warnings do not stop later `autoconf.sh` helpers.
