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
- `NET_GATEWAY=10.0.2.1`
- `NET_NAMESERVER=10.0.2.1`
- `NET_DOMAINNAME=retro.net`
- `NET_IFCONFIG_PATH` auto-detected
- `NET_ROUTE_PATH` auto-detected
- `NET_ETCPATH=/etc`
- `NET_RCPATH=$NET_ETCPATH/rc.d`
- `NET_MODULE=tulip`
- `NET_HOSTNAME_INIT_SET` unset

It then detects target paths:

- Hostname file: `$NET_ETCPATH/HOSTNAME` when present, otherwise
  `$NET_ETCPATH/hostname`.
- Command paths: `NET_IFCONFIG_PATH` and `NET_ROUTE_PATH` are preserved when
  already set; otherwise `/sbin`, then `/etc`, then the unqualified command
  name are used for each command independently.
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

- `NET_BROADCAST`
  IPv4 broadcast address. Defaults to `10.0.2.255`.

- `NET_GATEWAY`
  Default gateway. Defaults to `10.0.2.1`.

- `NET_NAMESERVER`
  DNS server. Defaults to `10.0.2.1`.

- `NET_IFCONFIG_PATH`
  Path or command name used for generated `ifconfig` lines. If unset,
  networking path detection probes `/sbin/ifconfig` and `/etc/ifconfig`, then
  falls back to `ifconfig`.

- `NET_ROUTE_PATH`
  Path or command name used for generated `route` lines. If unset, networking
  path detection probes `/sbin/route` and `/etc/route`, then falls back to
  `route`.

- `NET_ETCPATH`
  Target `/etc` path. Defaults to `/etc`.

- `NET_RCPATH`
  Target rc script path. Defaults to `$NET_ETCPATH/rc.d`.

## `x11.sh`

### Purpose

`x11.sh` generates XFree86 configuration for supported historical X11 server
layouts. The public wrapper in `common.sh` is:

- `configure_x11`
  Sources `config/x11.sh` and calls `_configure_x11`.

The generated configurations target QEMU-style Cirrus/VESA graphics and a
basic two- or three-button mouse setup.

### Configuration Flow

`_configure_x11`:

1. Detects mouse defaults once, preserving any manifest-supplied `MOUSEDEV` and
   `MOUSETYPE` values.
2. Selects the first supported X server in this order:
   `/usr/X11R6/bin/XFree86`, `/usr/X11R6/bin/XF86_SVGA`,
   `/usr/X386/bin/XF86_SVGA`, then `/usr/X386/bin/X386mono`.
3. Writes the matching X configuration file.
4. Installs an `X` symlink for layouts that require it.
5. Copies `XF86Config` to `/etc/XF86Config` for X11R6 layouts when the primary
   config path is elsewhere.
6. Installs the `startx` font-reset wrapper for `/usr/X386/bin/XF86_SVGA`.

Supported paths:

- XFree86 4.x
  Uses `/usr/X11R6/bin/XFree86`, writes `XF86Config`, selects the `vesa` driver,
  and uses the XFree86 4.x `ServerLayout` format.

- XFree86 3.x SVGA under X11R6
  Uses `/usr/X11R6/bin/XF86_SVGA`, writes `XF86Config`, and configures the
  `svga` screen with QEMU/Cirrus-safe options.

- X386/XFree86 SVGA
  Uses `/usr/X386/bin/XF86_SVGA`, writes the older `Xconfig` format, configures
  the `clgd5422` chipset, and wraps `startx` so `setfont` is run after X exits
  when available.

- X386 mono
  Selected when `/usr/X386/bin/X386mono` exists. The helper then uses
  `/usr/X386/bin/XF86_mono` when present, otherwise `/usr/X386/bin/X386mono`.
  It writes the older `Xconfig` format and selects the mono `VGA2` mode.

### Variables

- `MOUSEDEV`
  Mouse device. If unset, the helper prefers `/dev/psaux`, then `/dev/ps2aux`,
  then `/dev/cua1`.

- `MOUSETYPE`
  Mouse protocol. If unset, PS/2 devices use `PS/2` and `/dev/cua1` uses
  `Microsoft`.

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

- `enable_serial_console`
  Sources `config/tty.sh` and calls `_enable_serial_console`.

### Configuration Flow

`_enable_serial_console`:

1. Sets serial defaults for `TTYDEV` and `TTYBAUD`.
2. Reads `/etc/inittab` if present.
3. Looks for a commented stock serial getty line matching the requested TTY,
   falling back to a stock `ttyS0` line.
4. Reuses that stock line when found, updating the baud rate and TTY device.
5. Otherwise builds a getty line from either `agetty` or a getty_ps-compatible
   `getty`.
6. Saves `/etc/inittab.orig` and adds or enables the serial getty when one is
   not already active.
7. Comments out `CONSOLE` in `/etc/login.defs` when present so
   `/etc/securetty` controls root login devices.
8. Saves `/etc/securetty.orig` and appends the serial TTY to `securetty`.

### Variables

- `TTYDEV`
  Serial device name. Defaults to `ttyS0`.

- `TTYBAUD`
  Serial baud rate. Defaults to `9600`.

- `TTYID`
  Inittab identifier for newly appended getty lines. Defaults to `s0`.

- `TTYRUNLEVELS`
  Runlevels for newly appended getty lines. Defaults to `123456`.

- `TTYGETTY_STYLE`
  Set to `agetty` to force an `agetty`-style getty line when no stock line is
  available. Otherwise the helper uses `/sbin/getty` or `/etc/getty`.

- `TTYTERM`
  Terminal type for generated `agetty` lines. Defaults to `vt100`.

### Behavior Notes

- If `/etc/inittab` is missing, the helper does nothing.

- The helper does not de-duplicate `/etc/securetty`; it appends `TTYDEV` after
  saving the original file.

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
