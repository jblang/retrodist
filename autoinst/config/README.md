# Autoinstall Configuration Helpers

This directory contains first-boot configuration helpers used by
`autoconf.sh`. These scripts are copied into the staged installer media under
`autoinst.d/config/`.

The public helper functions are defined in `autoinst.d/common.sh`. Those
wrappers source the scripts in this directory and call the underscored
implementation functions here.

## Compatibility Notes

- These scripts run inside newly installed historical systems. More commands are
  available than in the installer environment, but they are still old and may
  lack modern options.

- Keep shell code portable. Prefer simple `test`, `sed`, `cp`, and shell
  redirection patterns that work on old `/bin/sh` implementations.

- Helpers generally save a backup before replacing or appending to generated
  configuration files. Backup suffixes are helper-specific (`~`, `.orig`, or
  Debian's `modules.old` marker). They are intended for first-boot automation,
  not repeated interactive reconfiguration.

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
- `NET_ETCPATH=/etc`
- `NET_RCPATH=$NET_ETCPATH/rc.d`
- `NET_MODULE=tulip`
- `NET_HOSTNAME_INIT_SET` unset

It then detects target paths:

- Hostname file: `$NET_ETCPATH/HOSTNAME` when present, otherwise
  `$NET_ETCPATH/hostname`.
- Command paths: `NET_IFCONFIG_PATH`, `NET_ROUTE_PATH`, and `NET_ARP_PATH`
  are preserved when already set; otherwise compatible default locations are
  probed before falling back to the unqualified command name.
- Startup path: `$NET_RCPATH/rc.inet1` first, then
  `$NET_ETCPATH/init.d/network` when `$NET_ETCPATH/init.d` exists, then
  `$NET_ETCPATH/rc.net`.

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

After networking configuration, the helper enables a network driver when a
known module loader layout exists:

- Debian-style `$NET_ETCPATH/init.d/modules`: splits `NET_MODULE` into a module
  name and optional arguments, appends only the module name to
  `$NET_ETCPATH/modules`, appends the `eth0` alias and any options to
  `$NET_ETCPATH/conf.modules`, and creates `$NET_ETCPATH/modules.old` as the
  historical Debian module-configuration marker.
- Slackware-style `$NET_RCPATH/rc.modules`: appends a `/sbin/modprobe` line for
  `NET_MODULE`.

Set `NET_MODULE=none` to skip module loading.

`net.sh` preserves the first backup it creates rather than refreshing backups
on later runs. Most network files use a `~` suffix; Debian module setup uses
`conf.modules~` plus the `modules.old` marker.

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

- `NET_MODULE`
  Optional network module line to load when a supported module loader exists.
  It may include module arguments. Defaults to `tulip`; set to `none` to skip
  module loading. Debian writes the module name to `/etc/modules` and writes
  arguments to `/etc/conf.modules` as an `options` line. Slackware passes the
  full value to `/sbin/modprobe` in `rc.modules`. ISA NE2000 profiles should
  set `NET_MODULE='ne io=0x300'`.

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

- `NET_ETCPATH`
  Target `/etc` path. Defaults to `/etc`.

- `NET_RCPATH`
  Target rc script path. Defaults to `$NET_ETCPATH/rc.d`.

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

- `X11_DEPTH`
  Default display depth for XFree86 3.x and 4.x `XF86Config`. Defaults to `16`.

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
2. Detects target paths under `TTY_ETCPATH` and reads `inittab` if present.
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

- `TTY_ETCPATH`
  Target `/etc` path. Defaults to `/etc`.

### Behavior Notes

- If `$TTY_ETCPATH/inittab` is missing, the helper does nothing.

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

- `configure_mail`
  Sources `config/mail.sh` and calls `_configure_mail`.

### Configuration Flow

`_configure_mail`:

1. Checks for sendmail at `/usr/sbin/sendmail` or `/usr/lib/sendmail`.
2. Leaves the system unchanged when `/etc/sendmail.cf` already exists.
3. Searches known source locations for a suitable sample configuration.
4. Copies the first matching sample to `/etc/sendmail.cf`.
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
