# Autoinstall Configuration Helpers

This directory contains first-boot configuration helpers used by
`autoconf.sh`. These scripts are copied into the staged installer media under
`autoinst.d/config/`.

The public helper functions are defined in `autoinst.d/common.sh`. Those
wrappers source the scripts in this directory and call the underscored
implementation functions here.

## Compatibility Notes

Refer to compatibility notes in ../README.md.

## `modules.sh`

### Purpose

`modules.sh` configures kernel module autoloading on the target system. The public wrapper in `common.sh` is:

- `mod_config`
  Sources `config/modules.sh` and calls `_mod_config`.

### Configuration Flow

`_mod_config`:

1. Detects the target layout by probing `$ETCPATH/rc.d/rc.modules` (Slackware)
   then `$ETCPATH/init.d/modules` or `$ETCPATH/init.d/modutils` (Debian). Logs
   a message and returns without error when neither is found.
2. Backs up existing module config files before the first modification.
3. Iterates `MOD_ENABLE` and enables each entry via `mod_enable`.

### Variables

- `MOD_ENABLE`
  Newline-separated list of module specs to enable at boot, one per line, in
  `name [options...]` format. Set in the distro manifest before calling
  `mod_config`.

### Behavior Notes

- Debian: appends the module name to `$ETCPATH/modules`; appends an `options`
  line to `$ETCPATH/conf.modules` when options are present.

- Slackware: appends `/sbin/modprobe name [opts]` to `$ETCPATH/rc.d/rc.modules`.

- Detection probes `$ETCPATH/init.d/modules` and `$ETCPATH/init.d/modutils`
  for Debian (covering Debian 1.3, which ships `modules` as a symlink to `modutils`).

## `net.sh`

### Purpose

`net.sh` configures basic networking for Debian, Slackware, and SLS target
layouts. The public wrapper in `common.sh` is:

- `net_config`
  Sources `config/net.sh` and calls `_net_config`.

### Configuration Flow

`_net_config` first sets defaults for the QEMU user-networking
environment:

- `NET_NETMASK=255.255.255.0`
- `NET_NETWORK=10.0.2.0`
- `NET_BROADCAST=10.0.2.255`
- `NET_GATEWAY=10.0.2.2`
- `NET_NAMESERVER=10.0.2.3`
- `NET_DOMAINNAME=retro.net`
- `NET_IFCONFIG_PATH` auto-detected
- `NET_ROUTE_PATH` auto-detected
- `NET_ARP_PATH` auto-detected
- `NET_HOSTNAME_INIT_SET` unset

It then detects target paths:

- Hostname file: `$ETCPATH/HOSTNAME` when present, otherwise
  `$ETCPATH/hostname`.
- Command paths: `NET_IFCONFIG_PATH`, `NET_ROUTE_PATH`, and `NET_ARP_PATH`
  are preserved when already set; otherwise compatible default locations are
  probed before falling back to the unqualified command name.
- Startup path: `$ETCPATH/rc.d/rc.inet1` first, then
  `$ETCPATH/init.d/network` when `$ETCPATH/init.d` exists, then
  `$ETCPATH/rc.net`.

It then applies the detected configuration:

- When an init-script path is detected:
  - Writes the hostname file, generated init script, `hosts`, and
    `resolv.conf`.
  - When `NET_HOSTNAME_INIT_SET=1`, the generated init script calls
    `hostname -S` before configuring network interfaces.
  - Appends `localnet $NET_NETWORK` to `/etc/networks` unless
    `NET_ANCIENT_ROUTE=1`.
- When `rc.net` is selected:
  - Updates `/etc/hosts` entries for the host, network, and router.

Network driver module loading is handled separately by `modules.sh` via
`MOD_ENABLE`; `net.sh` no longer configures kernel modules.

`net.sh` preserves the first backup it creates rather than refreshing backups
on later runs. Network files use a `~` suffix.

### Variables

- `NET_HOSTNAME`
  Target host name. This should normally be set by the distro manifest.

- `NET_IPADDR`
  Target IPv4 address. This should normally be set by the distro manifest.

- `NET_DOMAINNAME`
  DNS domain. Defaults to `retro.net`; set to empty or `none` for layouts that
  should not write domain/search records.

- `NET_NETMASK`
  IPv4 netmask. Defaults to `255.255.255.0`.

- `NET_NETWORK`
  IPv4 network address. Defaults to `10.0.2.0`.

- `NET_ANCIENT_ROUTE`
  Set to `1` for systems whose `route` command needs ancient syntax. This
  changes loopback routing to `route add 127.0.0.1`, changes the Ethernet
  network route to `route -n add $NETWORK`, and prevents generated init-script
  layouts from creating `/etc/networks`.

- `NET_HOSTNAME_INIT_SET`
  Set to `1` when the generated init script should call `hostname -S` before
  configuring network interfaces. Debian 0.91 uses this.

- `NET_GATEWAY_HWADDR`
  Optional Ethernet address for a static ARP entry for `$NET_GATEWAY`. Debian
  1.2 uses this because its ARP exchange with QEMU user networking can fail
  repeatedly after boot until enough outbound probes have been sent. QEMU
  slirp's gateway address is `52:55:0a:00:02:02`.

- `NET_NAMESERVER_HWADDR`
  Optional Ethernet address for a static ARP entry for `$NET_NAMESERVER`.
  Debian 1.2 sets this to QEMU slirp's nameserver address,
  `52:55:0a:00:02:03`.

- `NET_BROADCAST`
  IPv4 broadcast address. Defaults to `10.0.2.255`.

- `NET_GATEWAY`
  Default gateway. Defaults to `10.0.2.2`.

- `NET_NAMESERVER`
  DNS server. Defaults to `10.0.2.3`.

- `NET_IFCONFIG_PATH`
  Path or command name used for generated `ifconfig` lines. If unset,
  networking path detection probes `/sbin/ifconfig` and `/etc/ifconfig`, then
  falls back to `ifconfig`.

- `NET_ROUTE_PATH`
  Path or command name used for generated `route` lines. If unset, networking
  path detection probes `/sbin/route` and `/etc/route`, then falls back to
  `route`.

- `NET_ARP_PATH`
  Path or command name used for generated static ARP entries. If unset,
  networking path detection probes `/usr/sbin/arp` and `/sbin/arp`, then falls
  back to `arp`.

## `x11.sh`

### Purpose

`x11.sh` generates XFree86 configuration for supported historical X11 server
layouts. The public wrapper in `common.sh` is:

- `x11_config`
  Sources `config/x11.sh` and calls `_x11_config`.

The generated configurations target QEMU-style Cirrus/VESA graphics and a
basic two- or three-button mouse setup.

### Configuration Flow

`_x11_config`:

1. Detects mouse defaults once, preserving any manifest-supplied
   `X11_MOUSEDEV` and `X11_MOUSETYPE` values.
2. Selects the first supported X server in this order:
   `/usr/X11R6/bin/XFree86`, `/usr/X11R6/bin/XF86_SVGA`,
   `/usr/X386/bin/XF86_SVGA`, then `/usr/X386/bin/X386mono`.
3. Writes the matching X configuration file.
4. Installs an `X` symlink for layouts that require it.
5. Links `/etc/XF86Config` to the generated `XF86Config` for X11R6 layouts
   when the primary config path is elsewhere.
6. Installs the `startx` font-reset wrapper for `/usr/X386/bin/XF86_SVGA`.

Supported paths:

- XFree86 4.x
  Uses `/usr/X11R6/bin/XFree86`, writes `XF86Config`, selects the `vesa` driver,
  and uses the XFree86 4.x `ServerLayout` format.

- XFree86 3.x SVGA under X11R6
  Uses `/usr/X11R6/bin/XF86_SVGA`, writes `XF86Config`, and configures the
  `svga` screen with QEMU/Cirrus-safe options.

- XFree86 1.x/2.x SVGA under `/usr/X386`
  Uses `/usr/X386/bin/XF86_SVGA`, writes the older `Xconfig` format, links the
  server as `X` in `/usr/X386/bin`, configures the `clgd5422` chipset, and
  wraps `startx` so `setfont` is run after X exits when available.

- XFree86 1.x/2.x mono under `/usr/X386`
  Selected when `/usr/X386/bin/X386mono` exists. It writes the older `Xconfig`
  format, links the server as `X` in `/usr/X386/bin`, and selects the mono
  `VGA2` mode.

### Variables

- `X11_MOUSEDEV`
  Mouse device. If unset, the helper prefers `/dev/psaux`, then `/dev/ps2aux`,
  then `/dev/cua1`.

- `X11_MOUSETYPE`
  Mouse protocol. If unset, PS/2 devices use `PS/2` and `/dev/cua1` uses
  `Microsoft`.

- `X11_DEPTHS`
  Space-separated display depths in preference order. XFree86 3.x emits
  `Display` subsections in this order, using the first matching subsection as
  the default. XFree86 4.x emits the first depth as `DefaultDepth`. Defaults to
  `16 8 32`.

- `X11_MODES`
  Quoted X mode list for generated `Modes` lines. XFree86 3.x, XFree86 4.x,
  and XFree86 1.x/2.x SVGA default to `"1024x768" "800x600" "640x480"`.
  XFree86 1.x/2.x mono defaults to `"640x480"`.

### Behavior Notes

- Existing `XF86Config` or `Xconfig` files are copied to `.orig` before being
  replaced.

- The generated mode lists prioritize `1024x768`, with lower resolutions kept
  as fallbacks where the server format supports them.

- The `startx` wrapper is only installed when using the older
  `/usr/X386/bin/XF86_SVGA` path and only when `startx` is a regular file that
  has not already been wrapped.
## `tty.sh`

### Purpose

`tty.sh` enables a serial login console. The public wrapper in `common.sh` is:

- `tty_config`
  Sources `config/tty.sh` and calls `_tty_config`.

### Configuration Flow

`_tty_config`:

1. Sets serial defaults for `TTY_DEV` and `TTY_BAUD`.
2. Detects target paths under `$ETCPATH` and reads `inittab` if present.
3. Leaves `inittab` unchanged and logs a warning when an active getty line
   already exists for the requested TTY.
4. Looks for a commented stock serial getty line for serial ports 0 or 1
   (matching `ttyS[01]` or `ttys[01]`).
5. Uncomments and adapts the stock serial getty line, replacing the device name
   with the target device and using `TTY_ID` and `TTY_RUNLEVELS` for the
   inittab entry.
6. Saves `inittab.orig` and inserts the generated line after the matching stock
   comment.
7. Comments out `CONSOLE` in `login.defs` when present so `securetty` controls
   root login devices.
8. Saves `securetty.orig` when `securetty` already exists and appends the serial
   TTY when it is not already listed.

### Variables

- `TTY_DEV`
  Serial device name. Defaults to `ttyS0`.

- `TTY_BAUD`
  Serial baud rate. Defaults to `9600`.

- `TTY_ID`
  Inittab identifier for newly appended getty lines. Defaults to the serial
  device suffix (`s0` for `ttyS0`/`ttys0`, `s1` for `ttyS1`/`ttys1`, and so on).

- `TTY_RUNLEVELS`
  Runlevels for newly appended getty lines. Defaults to `123456`.

### Behavior Notes

- If `$ETCPATH/inittab` is missing, the helper does nothing.

- `ttyS` and older `ttys` serial device spellings are treated as equivalent
  when matching existing `inittab` lines.

- The helper preserves the first `.orig` backup it creates and does not refresh
  that backup on later runs.

- TTY-specific failures are logged as warnings and do not stop later
  `autoconf.sh` helpers from running.

- The helper requires a commented stock serial getty line in `inittab` to work.
  If no such line is found, it logs a warning and leaves `inittab` unchanged.


## `mail.sh`

### Purpose

`mail.sh` installs a basic sendmail configuration when sendmail exists but
`/etc/sendmail.cf` does not. The public wrapper in `common.sh` is:

- `mail_config`
  Sources `config/mail.sh` and calls `_mail_config`.

### Configuration Flow

`_mail_config`:

1. Checks for sendmail at `/usr/sbin/sendmail` or `/usr/lib/sendmail`.
2. Leaves the system unchanged when `$ETCPATH/sendmail.cf` already exists.
3. Searches known source locations for a suitable sample configuration.
4. Copies the first matching sample to `$ETCPATH/sendmail.cf`.
5. Sets the copied file mode to `644`.

### Candidate Files

The helper searches these files in order:

- `/usr/src/sendmail/linux.smtp.cf`
- `/usr/src/sendmail/cf/obj/tcpproto.cf`
- `/usr/src/sendmail/linux.uucp.cf`
- `/usr/src/sendmail/cf/obj/uucpproto.cf`

### Behavior Notes

- If sendmail is missing, no configuration is installed.

- If none of the candidate files exists, no configuration is installed.
