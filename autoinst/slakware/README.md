# Slackware Autoinstall Scripts

This directory contains the Slackware-specific install helpers used by `autoinst.sh`.

## Layout

- `sysinst/default.sh`
  Shared installer for the early SLS-style `sysinstall` based Slackware releases.

- `pkginst/111.sh`
  Wrapper for Slackware `1.1.1` `pkgtool`.

- `pkginst/112+.sh`
  Wrapper for the Slackware `1.1.2+` `pkgtool` family.

- `pkginst/shared.sh`
  Common helper used by the `pkgtool` wrappers.

## Package Skips

Slackware `pkgtool` installs can define per-distribution package skips in
`pkgskip.txt` next to each distro's `config.sh`. During extraction, `retro`
generates tagfiles from the package directories and marks every package listed
in `pkgskip.txt` as `SKP`.

## Compatibility Note

The staged install disk is mounted as plain DOS on some historical Slackware installers.
This helper tree therefore uses `slakware/` instead of `slackware/` so the staged path
fits within DOS 8.3 filename limits.
