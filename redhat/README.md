# Red Hat Linux

These configs stage and boot early Intel Red Hat Linux releases, covering the
pre-RHEL line from Red Hat Commercial Linux 1.1 through Red Hat Linux 6.1.

## Release Matrix

This table summarizes the Red Hat releases represented in this repo and their
current automation status.

| Release | Codename | Automation |
| --- | --- | --- |
| [1.1](./1.1-infomagic/README.txt) | Mother's Day + 0.1 | Scripted install; package installation fails |
| [2.1](./2.1-infomagic/README.txt) | Bluesky | Scripted UI install |
| [3.0.3](./3.0.3-infomagic/README.txt) | Picasso | Scripted UI install |
| [4.0](./4.0-infomagic/README.txt) | Colgate | Scripted UI install |
| [4.1](./4.1-infomagic/README.txt) | Vanderbilt | Scripted UI install |
| [4.2](./4.2-infomagic/README.txt) | Biltmore | Scripted UI install |
| [5.0](./5.0-infomagic/README.txt) | Hurricane | Scripted UI install |
| [5.1](./5.1-infomagic/README.txt) | Manhattan | Scripted UI install |
| [5.2](./5.2-infomagic/README.txt) | Apollo | Kickstart install |
| [6.1](./6.1-infomagic/README.txt) | Cartman | Scripted text install; installed system does not boot |

## Historical Background

- [Wikipedia article](https://en.wikipedia.org/wiki/Red_Hat_Linux)
- [Red Hat Linux](https://en.wikipedia.org/wiki/Red_Hat_Linux) was the
  community Linux distribution line that preceded Red Hat Enterprise Linux.

## Installation

Run a scripted install when the selected version's `config.toml` selects an
installer driver:

```sh
retro install redhat/VERSION-infomagic
```

For example:

```sh
retro install redhat/5.2-infomagic
```

For the original manual install flow, use `retro boot` and follow the release's
own installer prompts:

```sh
retro boot redhat/VERSION-infomagic
```

When prompted to change floppy disks, use `qmp change-image IMAGE`. Early
versions need this during boot:

```sh
qmp change-image ramdisk1.img
qmp change-image ramdisk2.img
qmp change-image rootdisk.img
qmp change-image boot.img
```

## Kickstart

If a Red Hat config directory or its parent contains `ks.cfg`, `retro extract`
copies a comment-stripped and empty-line-stripped copy into the root of the
staged boot floppy image as `ks.cfg`.

Red Hat 5.2 currently provides a Kickstart file. Its declarative boot command is:

```sh
linux ks=floppy
```

Kickstart staging only modifies an existing `boot.img`; it does not create a
separate Kickstart floppy.

## Scripted Installs

The Python family drivers send boot commands and change floppy images when the
installer asks for another disk. Release-specific prompts and flags are
declared in each `config.toml`.

The older Red Hat installers are less uniform than Slackware's setup scripts,
but they now share driver blocks by installer family:

- `redhat_dialog.py` covers the 1.1 through 3.0.3 Perl/dialog-based era. It
  replaces the installer's `dialog` executable with the serial adapter at its
  first widget, then matches structured widget titles, items, and prompt text.
  It uses Perl to rename the original binary because these root disks do not
  include `mv`. Screens that do not use the dialog stub remain VGA-driven.
  The release flow and package series stay in each release's TOML.
  Set the required `install.redhat.package_series` array to series names without
  the size prefixes shown by 3.0.3. Each config lists disabled series as
  commented array entries so they can be enabled directly. The
  `[install.locale]` table configures the hardware clock mode, time zone, and
  keyboard map selected by the installer. `install.redhat.root_password`
  configures the root password; optional `user` and `user_home` settings create
  one regular account. Early Red Hat limits the user name to eight characters.
- `redhat_newt.py` covers the 4.0 through 5.1 C-based text installer era. Version
  configs select independent `partitioning`, `mouse_setup`, `x11_setup`, and
  `network_setup` screen workflows instead of a release-number flow. The
  configured values describe the screens directly: partitioning uses
  `partition-disks`, `select-root-partition`, or `current-disk-partitions`;
  mouse setup uses `configure-mouse`, `probe-and-emulation`, or
  `probe-and-configure-mouse`; X11 uses `choose-card` or `pci-probe`; and
  networking uses `direct` or `probe-static`. The
  required `tcp_ip_form` distinguishes 4.0's network/broadcast fields from the
  gateway/nameserver fields used by 4.1 and later. Prompt-order settings cover
  dialogs that only some releases display, while `x_card_label` and
  `x_video_memory_label` hold exact rendered menu entries. The
  `password_field` and `boot_label_field` settings capture 5.1's shorter field
  labels. The required
  `install.redhat.components` array names the exact visible component groups to
  install. The driver selects listed groups and clears every unlisted group,
  including installer defaults. Each config keeps the other available groups as
  commented array entries so the complete release-specific catalog is visible
  and groups can be enabled directly. The mandatory Base component is implicit.
  Other single-choice menus are also selected explicitly, even when the desired
  entry is already the default, so the installation log records choices such as
  English, local CD-ROM media, IDE/ATAPI, Generic Monitor, no clockchip setting,
  and the target disk's master boot record.
  Its `NewtDialog` layer waits for a delimiter-bounded dialog title and drives
  named buttons, fields, menus, and checklists from QMP VGA cells. Titles and
  dialog borders are recognized from CP437 box characters; widget markers and
  colors identify entries and control state. A complete border must be present
  before interaction begins, after which captures stop at that dialog's bottom
  border. Fields are matched by exact rendered labels and verified together
  after editing, before the dialog advances. Dialog waits use `⏳`, each match
  logs one `📸` snapshot, and actions use an icon plus a concise verb such as
  `Press`, `Edit`, `Select`, or `Clear` without repeating the dialog title.
  F12 skips slow button animation; button labels are retained only where focus
  determines the result, while ordinary acceptance uses the rendered default.
  The `[install.locale]` table selects `hardware_clock` (`utc` or `local`),
  the exact visible `timezone`, and the exact visible `keymap`.
  The InfoMagic disc 1 images for 4.0 through 5.1 contain the matching installer
  trees under `misc/src/install/`. The 4.0 renderer and X sources are under
  `code/newt/` and `code/Xconfigurator/`. The 4.2 utility sources are on disc 5
  under `RedHat.SRC/SRPMS/`; 5.0 sources are in disc 1 `SRPMS/`; and 5.1 splits
  them between disc 1 `SRPMS/SRPMS.pt1/` and disc 5 `SRPMS.pt2/`. The audited
  packages are `timeconfig`, `kbdconfig`, `mouseconfig`, and `Xconfigurator`.
- 5.2 uses the installer Kickstart support instead of driving every screen.
- 6.1 currently boots the text installer from the CD-ROM media; Kickstart is
  not configured for it.

After installation, each scripted version runs its configured `[postinst]`
stages. The launcher mounts the staged FAT disk at `/retro` when needed. Later
versions set `postinst.x11.chipset = "clgd5446"` to match the emulated Cirrus
Logic video hardware.

## Known Issues

- Red Hat 1.1 manual installation currently fails during package installation.
- Red Hat 5.0 and 5.1 claim to support Kickstart on their LILO boot screens,
  but this has not worked reliably here, so those versions use UI-driving
  scripts instead.
- Red Hat 6.1 graphical installation is illegibile under QEMU's Cirrus Logic
  emulation. Use text mode. After installation, it won't boot due to IDE
  contoller interrupt errors.
