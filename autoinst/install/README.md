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

- `slackware_sysinstall`
- `sls_sysinstall`

Slackware 1.01-style flow:

1. Uses `SYSINSTALL_INSTSRC`, defaulting to `$INSTMOUNT/packages`.
2. Chooses `SYSINSTALL_MODE`, or detects `tex`, `X11`, or `mini`.
3. Creates target install bookkeeping directories.
4. Runs `sysinstall -instsrc ... -instroot ... -$INSTTYPE`.
5. Installs `fstab.tmp` as `/etc/fstab` when present.
6. Writes `/etc/hwconfig`.
7. Runs `etc/syssetup` with canned answers.
8. Installs the first-boot `autoconf.sh` hook through `/etc/rc.local`.

SLS flow:

1. Uses `SLS_INSTALL_MODE`, or detects `all`, `base`, or `mini`.
2. Creates target install bookkeeping directories.
3. Installs mounted `/user` disk packages.
4. Installs series `a`; adds `b` and `c` for `base` or `all`; adds `x` for
   `all`.
5. Installs `fstab.tmp` as `/etc/fstab` when present.

Variables:

- `SYSINSTALL_INSTSRC`: Slackware source path. Default:
  `$INSTMOUNT/packages`.
- `SYSINSTALL_MODE`: Slackware mode such as `mini`, `X11`, `tex`, or
  `everything`.
- `SYSSETUP_PROFILE`: set to `sls103` for the SLS 1.03 answer sequence.
- `VGAMODE`: value for `/etc/hwconfig`. Default: `-1`.
- `SLS_INSTALL_MODE`: `mini`, `base`, or `all`.
