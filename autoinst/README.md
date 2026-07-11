# Autoinstall Scripts

This directory contains the helper scripts copied onto staged installer media
for installation and first-boot configuration.

`retrolib/extract.sh` stages this tree during `retro extract` with
`autoinst_prep`: it copies this directory to `qemu.d/fat/autoinst.d`, and
copies the distro's `autoconf.sh` manifest to `qemu.d/fat/autoinst.d/distro/`.

For the host-side staging process and config file lookup rules, see
[retrolib/README.md](../retrolib/README.md). For adding a new distro manifest,
see [CONTRIBUTING.md](../CONTRIBUTING.md).

## Reference vs. Staged Files

Do not edit `qemu.d/fat/autoinst.d/` files directly. They are generated copies
staged for automated installs and will be overwritten.

Edit the source files instead:

- Shared runtime and helper scripts live in this `autoinst/` directory.
- Debian per-version install manifests live under `debian/VERSION/`.
- Slackware per-version or per-variant manifests live under `slackware/`.
- Other distro manifests live beside their distro config.

## Compatibility Notes

- These scripts run in very old installer and target-system environments. Keep
  shell code portable and avoid modern shell features.

- Never use command status negation such as `if ! command; then`.
  - Some old versions of bash treat `!` as a command and print `!: not found`. 
  - This causes old ash versions run the right-hand function in a subshell,
    so any variables set inside the function are discarded when the subshell exits.
  - Negation inside `test` such as `[ ! -f file ]` is fine.

- Install scripts run from the installer media with a limited command set. `sed`
  and `cut` are usually available; tools such as `grep`, `awk`, `which`, and
  `command -v` may be missing.

- Configuration scripts run after the base system has been installed, so more
  commands are usually available, but they are old versions and may lack modern
  options.

- Some installers mount the staged disk as plain `msdos`, so helper filenames
  and directory layout need to remain DOS-friendly.

## `autoconf.sh`

`autoconf.sh` is the first-boot configuration runner. Distro install paths that
need a post-install configuration pass copy it into the target system and
arrange for it to run on boot.

At runtime it:

1. Extends `PATH` with common installed-system binary locations.
2. Mounts the staged install disk from `/dev/hdb1` at `/retro`.
3. Verifies that `/retro/autoinst.d` exists.
4. Sources `logging.sh` and defines public wrapper functions (`mod_config`,
   `net_config`, `tty_config`, `x11_config`) that load their implementation
   scripts on demand.
5. Initializes logging with `AUTOINST_DEBUG=0` unless overridden and
   `AUTOINST_LOG=/autoinst.log` unless overridden.
6. Sources `/retro/autoinst.d/distro/autoconf.sh`.
7. Removes the running script so it does not run again.
8. Syncs and reboots unless `AUTOCONF_REBOOT` is `0`, `false`, or `no`.

The distro `autoconf.sh` manifest is responsible for setting configuration
variables and calling wrappers such as `mod_config`, `net_config`,
and `x11_config`.

## `dialog.sh`

`dialog.sh` adapts dialog-based installers, including Slackware's color `setup`
and early Debian and Red Hat installers, for host-side scripting. When serial
is available, it sends labeled widget fields to the host and reads the scripted
answer from the same port.

The adapter never executes the real dialog binary: installers often redirect
dialog's stderr into result files, and any screen drawing would pollute them.
The plain-text transcript is echoed to the console for progress indication,
using the fd opposite the widget result (stdout normally, stderr under
`--stdout`) so redirected results stay clean. Infobox widgets are muted on
the serial transcript by default; set `DIALOG_SERIAL_INFOBOXES=1` to include
them.

## `logging.sh`

`logging.sh` provides portable echo-based logging helpers. Messages are written
to stderr with bright ANSI-colored prefixes, and are appended without color to
`$AUTOINST_LOG` when that variable is set.

Logging helpers:

- `log_debug`
  Logs a `DEBUG:` message only when `AUTOINST_DEBUG=1`.

- `log_info`
  Logs an `INFO:` message.

- `log_warn`
  Logs a `WARN:` message.

- `log_error`
  Logs an `ERROR:` message.

- `log_attention`
  Logs an `ATTN:` message for interactive prompts or important operator
  attention.

- `log_div`
  Logs an 80-column divider line.

- `die`
  Logs an `ERROR:` message and exits 1. Use for critical steps whose failure
  would leave a broken or partial guest.

## `config/`

`config/` contains first-boot configuration helpers loaded through wrapper
functions defined in `autoconf.sh`.
See [config/README.md](config/README.md) for details.

## Distro Manifests

Each supported distro directory can provide an `autoconf.sh` first-boot
configuration manifest, copied to `autoinst.d/distro/autoconf.sh`.

The manifest should set only the variables needed by that distro and call the
public wrappers from `autoconf.sh`. Helper implementation code should stay in
this directory as function-only scripts so it can be sourced safely by the
runner.
