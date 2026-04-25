# Slackware Autoinstall Scripts

This directory contains the Slackware-specific install helpers used by `autoinst.sh`.

## Layout

- `sysinst/default.sh`
  Shared installer for the early SLS-style `sysinstall` based Slackware releases.

- `pkginst/111.sh`
  Wrapper for the Slackware `1.1.1` / `1.1.2` family.

- `pkginst/200.sh`
  Wrapper for the Slackware `2.0+` `pkgtool` family.

- `pkginst/shared.sh`
  Common helper used by the `pkgtool` wrappers.

## Compatibility Note

The staged install disk is mounted as plain DOS on some historical Slackware installers.
This helper tree therefore uses `slakware/` instead of `slackware/` so the staged path
fits within DOS 8.3 filename limits.

For Slackware autoinstall, the staged source disk is mounted at `/mnt` as
`SOURCEMOUNT`. The destination root is mounted separately as `TARGETMOUNT`
so the same source mount path can be used across distro families.
