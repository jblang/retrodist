# Red Hat Linux

These configs stage early Red Hat installer media from InfoMagic Linux
Developer's Resource CD-ROM sets.

## Status

Red Hat configs currently support download, extraction, and booting install
media. Scripted unattended installs are not implemented.

Use `retro boot` for manual installation:

```sh
retro boot redhat/VERSION/VARIANT
```

When prompted to change disks, use `qmp change-image`.

## InfoMagic variants

- `1.1/infomagic`: Red Hat Mother's Day + 0.1 from LDR 1995_08, disc 4.
- `2.1/infomagic`: Red Hat 2.1 from LDR 1995_11, disc 2.
- `3.0.3/infomagic`: Red Hat 3.0.3 from LDR 1996_04, disc 2.
