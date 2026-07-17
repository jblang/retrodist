# AGENTS.md

Guidance for AI agents working in this repository.

## What This Is

Retro Distro Playground downloads, stages, boots, and installs early Linux
distributions in QEMU, with scripted unattended installs where supported.

## Start Here

- User-facing overview: [README.md](README.md)
- Commands and VM operation: [USAGE.md](USAGE.md)
- Adding or maintaining distro configs: [CONTRIBUTING.md](CONTRIBUTING.md)
- Python host implementation and API documentation: [`hostlib/`](hostlib)
- In-guest installation runtime: [guestlib/README.md](guestlib/README.md)

Use `slackware/3.0/walnut/` as a compact working config example.

## Entry Points

```bash
retro boot CONFIG       # download, extract, and boot
retro install CONFIG    # run scripted install when supported
retro extract CONFIG    # stage files into qemu.d/
retro download CONFIG   # download source media
retro reset CONFIG      # remove generated qemu.d/ state
retro package CONFIG    # build a portable qemu.d/ tar

./retro-prereq          # install host tools and create .venv

qmp dump-screen
qmp send-text -n 'text'
qmp send-key ret
qmp change-image root.img
qmp eject-disk
```

`retro` and `qmp` are Python entry points configured by `pyproject.toml`.
`retro-prereq` is the standalone Bash bootstrap script.

## Hard Rules

- Do not edit staged guest-library copies under `qemu.d/fat/guestlib.d/`.
- Edit source files instead: `hostlib/`, `guestlib/`, distro `config.toml`,
  custom scripts, and the relevant config directory.
- Treat `qemu.d/`, `download.d/`, and `tagfile.d/` as generated state unless
  the task explicitly targets generated artifacts.
- Treat `config.toml` as authoritative. Use custom scripts only for extraction
  or post-install behavior that the declarative path cannot express.

## Validation

Run cheap local checks after source changes:

```bash
git diff --check
python3 -m unittest tests.test_python
tests/unit.sh
```

Full `retro install ...` runs are useful but expensive and often manual. Run
them only when the task calls for VM-level verification.

After code or config changes, review related documentation for needed updates.
Check the nearest README plus any linked reference doc, such as
[CONTRIBUTING.md](CONTRIBUTING.md) or [guestlib/README.md](guestlib/README.md).

## Compatibility Verification

After editing `guestlib/`, verify the change against the portability constraints
in [guestlib/README.md](guestlib/README.md). These scripts run in very old
installer environments. Check especially for:

- `if ! command; then`
- Bash-only syntax in `sh` files
- reliance on `grep`, `awk`, `which`, or `command -v`
- non-DOS-friendly staged filenames or paths
