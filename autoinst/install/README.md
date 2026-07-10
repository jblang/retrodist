# Autoinstall Install Helpers

These scripts run from `autoinst.sh` inside old installer environments. They
are copied to `autoinst.d/install/` and loaded through wrappers in
`autoinst.d/common.sh`.

## Compatibility

- Keep shell portable; assume old `sh`, old Bash, and small installer toolsets.
- Do not use command negation such as `if ! command; then`. Some old Debian
  installer Bash versions treat `!` as a command. `[ ! -f file ]` is fine.
- Do not assume `which`, `command -v`, `grep`, or `awk` exist.
- Keep helper names and staged paths DOS-friendly because some installers mount
  the staged disk as `msdos`.

## `sysinst.sh`

Wrappers:

- `sls_sysinstall`

SLS flow:

1. Uses `SLS_INSTALL_MODE`, or detects `all`, `base`, or `mini`.
2. Creates target install bookkeeping directories.
3. Installs mounted `/user` disk packages.
4. Installs series `a`; adds `b` and `c` for `base` or `all`; adds `x` for
   `all`.
5. Installs `fstab.tmp` as `/etc/fstab` when present.

Variables:

- `SLS_INSTALL_MODE`: `mini`, `base`, or `all`.
