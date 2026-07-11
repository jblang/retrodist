# AGENTS.md

Guidance for AI agents working in this repository.

## What This Is

Retro Distro Playground downloads, stages, boots, and installs early Linux
distributions in QEMU, with scripted unattended installs where supported.

## Start Here

- User-facing overview and commands: [README.md](README.md)
- Adding or maintaining distro configs: [CONTRIBUTING.md](CONTRIBUTING.md)
- Host-side library details: [retrolib/README.md](retrolib/README.md)
- In-guest autoinstall runtime: [autoinst/README.md](autoinst/README.md)
- Jump box details: [JUMP.md](JUMP.md)

Use `slackware/3.0/walnut/` as a compact working config example.

## Entry Points

```bash
retro boot CONFIG       # download, extract, and boot
retro install CONFIG    # run scripted install when supported
retro extract CONFIG    # stage files into qemu.d/
retro download CONFIG   # download source media
retro reset CONFIG      # remove generated qemu.d/ state
retro package CONFIG    # build a portable qemu.d/ tar
retro prereq            # install host dependencies

jump run                # start the Debian jump box
jump ssh|sftp|scp       # connect to the jump box

qmp dump-screen
qmp send-text -n 'text'
qmp send-key ret
qmp change-image root.img
qmp eject-disk
```

Extra arguments after `CONFIG` are passed to QEMU.

## Hard Rules

- Do not edit staged autoinstall copies under `qemu.d/fat/autoinst.d/`.
- Edit source files instead: `autoinst/`, distro `autoconf.sh` manifests, and
  the relevant config directory.
- Treat `qemu.d/`, `download.d/`, and `tagfile.d/` as generated state unless
  the task explicitly targets generated artifacts.

## Validation

Run cheap local checks after source changes:

```bash
git diff --check
tests/unit.sh
```

Full `retro install ...` runs are useful but expensive and often manual. Run
them only when the task calls for VM-level verification.

After code or config changes, review related documentation for needed updates.
Check the nearest README plus any linked reference doc, such as
[CONTRIBUTING.md](CONTRIBUTING.md), [retrolib/README.md](retrolib/README.md),
or [autoinst/README.md](autoinst/README.md).

## Compatibility Verification

After editing `retrolib/`, verify the change against the Compatibility Notes in
[retrolib/README.md](retrolib/README.md). Check especially for Bash 4+ syntax
and GNU-only command flags.

After editing `autoinst/`, verify the change against the portability constraints
in [autoinst/README.md](autoinst/README.md). These scripts run in very old
installer environments. Check especially for:

- `if ! command; then`
- Bash-only syntax in `sh` files
- reliance on `grep`, `awk`, `which`, or `command -v`
- non-DOS-friendly staged filenames or paths
