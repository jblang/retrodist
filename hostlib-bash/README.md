# Legacy Bash Host Runtime

This directory contains the legacy Bash host used by `retro-bash` and
`qmp-bash`. The supported Python host is the `hostlib/` package.

The Bash implementation continues to read historical `download.txt`,
`cdrom.txt`, `slackmirror.txt`, `debmirror.txt`, `extract.sh`, `qemu.sh`,
`install.sh`, and `postinst.sh` inputs. Python does not use these files as
configuration sources. New configuration belongs in `config.toml`.

## Commands

The legacy entry points remain available from the repository root:

```bash
retro-bash COMMAND [CONFIG]
qmp-bash COMMAND [OPTIONS]
```

`retro-bash` supports `help`, `boot`, `install`, `extract`, `download`,
`tagfile`, `package`, `prereq`, and `reset`. `qmp-bash` supports VGA screen
dumps, keyboard input, and removable-media control through QMP pipes.

## Modules

| Area | Modules |
|---|---|
| CLI operations | `prereq.sh`, `download.sh`, `extract.sh`, `qemu.sh` |
| QEMU assembly | `qemu-config.sh`, `qemu-devices.sh`, `qemu-network.sh`, `qemu-command.sh` |
| Automation | `script.sh`, `script-kb.sh`, `script-vga.sh`, `script-serial.sh`, `script-dialog.sh`, `script-fdisk.sh` |
| Transport | `qmp.sh` |

The top-level Bash launchers set `HOSTLIB_D` to this directory and source these
modules. Custom extraction scripts invoked by Python receive the same path in
`HOSTLIB_D`, but Python never reads configuration variables back from them.

## Compatibility Notes

The legacy host supports the system Bash 3.2 on macOS and modern Bash on Linux.
When changing it:

- avoid Bash 4 features such as associative arrays, `mapfile`, and `|&`;
- avoid GNU-only command flags when a BSD equivalent differs;
- quote paths and preserve array argument boundaries;
- keep QMP framing inside `qmp.sh`;
- keep media changes and keyboard behavior in their existing helper modules;
- run `tests/unit.sh` and `tests/shellcheck.sh` when available.

The Bash implementation is scheduled for removal. Keep compatibility changes
narrow and do not introduce shell parsing into the Python `hostlib/` package.
