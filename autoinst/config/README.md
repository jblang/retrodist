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

- Most helpers overwrite generated configuration files after saving `.orig`
  copies where practical. They are intended for first-boot automation, not
  repeated interactive reconfiguration.

## `net.sh`

### Purpose

`net.sh` configures basic networking for Debian, Slackware, and SLS target
layouts. The public wrapper in `common.sh` is:

- `configure_networking`
  Sources `config/net.sh` and calls `_configure_networking`.

### Configuration Flow

`_configure_networking` first sets defaults for the QEMU user-networking
environment:

- `NETMASK=255.255.255.0`
- `NETWORK=10.0.2.0`
- `BROADCAST=10.0.2.255`
- `GATEWAY=10.0.2.2`
- `NAMESERVER=10.0.2.1`
- `DOMAINNAME=retro.net`
- `ETCPATH=/etc`
- `RCPATH=$ETCPATH/rc.d`

It then chooses one of three target layouts:

1. `rc.inet1` layout
   Used by Slackware-style systems and some early Debian-derived layouts. The
   helper rewrites `HOSTNAME`, replaces `rc.inet1`, configures loopback and
   `eth0`, writes default routing, rewrites `hosts` and `resolv.conf`, and
   writes `networks` for the Debian `debra.debian.org` layout.

2. `init.d/network` layout
   Used by later early-Debian systems. The helper writes `hostname`, `networks`,
   `resolv.conf`, `hosts`, and a replacement `init.d/network` script. When
   `DEBIAN_GUARD_ETH0` is set, the generated network script only adds `eth0`
   routes if `ifconfig eth0 ...` succeeds.

3. `rc.net` layout
   Used by SLS. The helper updates `/etc/hosts` entries for the host, network,
   and router because this layout does not use the same startup networking files
   as Debian or Slackware.

After layout-specific configuration, the helper enables the NE2000 driver in
`rc.modules` when that file exists by uncommenting a matching `modprobe ne`
line and using I/O address `0x300`.

### Variables

- `HOSTNAME`
  Target host name. This should normally be set by the distro manifest.

- `IPADDR`
  Target IPv4 address. This should normally be set by the distro manifest.

- `DOMAINNAME`
  DNS domain. Defaults to `retro.net`; set to empty or `none` for layouts that
  should not write domain/search records.

- `NETMASK`
  IPv4 netmask. Defaults to `255.255.255.0`.

- `NETWORK`
  IPv4 network address. Defaults to `10.0.2.0`.

- `BROADCAST`
  IPv4 broadcast address. Defaults to `10.0.2.255`.

- `GATEWAY`
  Default gateway. Defaults to `10.0.2.2`.

- `NAMESERVER`
  DNS server. Defaults to `10.0.2.1`.

- `ETCPATH`
  Target `/etc` path. Defaults to `/etc`.

- `RCPATH`
  Target rc script path. Defaults to `$ETCPATH/rc.d`.

- `DEBIAN_GUARD_ETH0`
  When set, generated Debian `init.d/network` scripts guard `eth0`
  configuration so systems without the expected NIC can still boot cleanly.

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
