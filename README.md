# Retro Distro Playground

Linux used to arrive on stacks of floppy disks, mail-order CD-ROMs, and FTP
mirrors. Installing it meant choosing a kernel disk, swapping media, learning a
new partitioning tool, and hoping your video card appeared in a very long list.

Retro Distro Playground makes those old releases easy to visit. Pick a distro
and it fetches the original media, prepares a period-appropriate virtual
machine, and boots it in QEMU. Most releases can even run their original
installer automatically, leaving you with a working system to explore.

![Slackware running chi tao tao](screenshots/chitaotao.png)
![Early X11 desktop](screenshots/x11111.png)

## One-Time Setup

You need a Unix-like environment: Linux, macOS with
[Homebrew](https://brew.sh/), or Windows through
[WSL2](https://learn.microsoft.com/en-us/windows/wsl/install) or
[MSYS2](https://www.msys2.org/).

From the repository root, run:

```bash
./retro-prereq
```

You only need to run `retro-prereq` once. It installs the prerequisites and
creates the project's virtual environment. Feel free to check it out before
running it; it's a roughly 140-line shell script that installs the requisite
packages using the native package manager and `pip`.

## Take It for a Spin

Activate the environment in each new shell and pick a distro:

```bash
source .venv/bin/activate
retro install slackware/2.3/walnut
```

The first run downloads the historical media, so it may take a while. Then a
QEMU window opens and retrodist drives the original installer. When it finishes,
you can log in and poke around just as you would have in 1995.

Want the unassisted experience? Use `boot` instead of `install` and take over
at the first prompt:

```bash
retro boot slackware/2.3/walnut
```

Run `retro --help` for the command list. The [usage guide](USAGE.md) covers
manual installs, resetting a machine, networking, file transfer, and QEMU
controls.

## After the Install

`install` is a one-time job for each virtual machine. After it succeeds, do not
run it again for ordinary use. From then on, start the installed system with:

```bash
retro boot slackware/2.3/walnut
```

The automated installs use deliberately simple museum-machine credentials:

- Slackware, Debian 0.91, and Red Hat Linux 3.0.3 log in as `root` with no
  password.
- Debian 1.1 uses `root` / `password1`; it also creates
  `debian` / `password1`.
- Red Hat Linux 4.2 and 5.1 use `root` / `password`.

### What Still Feels Familiar

Much of the guest will feel familiar to a current Linux user. The filesystem
layout, shell, pipes, redirection, manual pages, users and groups, device files,
and tools such as `ls`, `grep`, `find`, `vi`, and `gcc` are all recognizably
Linux. A few good first commands are:

```sh
uname -a
cat /etc/issue
df
free
ps ax
```

Networking has the same basic model, but predates `ip` and NetworkManager. Use
the older tools to see the interface and routing table:

```sh
ifconfig
route -n
```

The guest sits behind QEMU's user-mode network and normally has outbound
access. Keep expectations period-appropriate: old browsers and network clients
usually cannot handle the encryption used by today's internet.

### What Needs Explaining

Graphical desktops often start from the text console rather than a graphical
login screen:

```sh
startx
```

Package management depends on the distro. These commands show what is
installed:

```sh
ls /var/adm/packages | less   # Slackware
dpkg -l | less                # Debian
rpm -qa | less                # Red Hat Linux
```

The biggest differences are in system administration. `sudo`, `systemd`,
`systemctl`, and modern service managers are generally absent. You will often
work as `root`, configure files directly under `/etc`, and start services from
scripts in `/etc/rc.d` or `/etc/init.d`.

### Halt Before Closing the VM

Before closing the QEMU window, **always halt the guest cleanly**. Run this as
`root` and wait for the system to report that it has halted:

```sh
halt
```

These old kernels usually cannot turn off the emulated machine themselves.
Once the guest has halted, close the QEMU window or press `Ctrl-C` in the
terminal running `retro`. Closing QEMU first is the equivalent of pulling the
power plug and can corrupt the guest filesystem.

## A Tour Through Early Linux

There are a lot of releases here. These make a good chronological tour:

### The beginnings: 1993–1994

- **Slackware 1.01** is one of the first recognizable Linux distributions,
  still rooted in the Linux 0.99 and floppy-disk era. Try
  `retro install slackware/1.01/channel1`.
- **Debian 0.91** shows Debian before its first stable release, with its early
  package tools and installation philosophy already taking shape. Try
  `retro install debian/0.91/infomagic`.

### The classic mid-1990s: 1995–1997

- **Slackware 2.3** is a mature Linux 1.2 system from the classic a.out era,
  just before Slackware's move to ELF. It is a great first stop. Try
  `retro install slackware/2.3/walnut`.
- **Debian 1.1 “Buzz”** is early stable Debian: deliberately organized,
  package-driven, and quite different from Slackware. Try
  `retro install debian/1.1/infomagic`.
- **Red Hat Linux 3.0.3 “Picasso”** offers an early look at the Red Hat style
  that would shape commercial Linux. Try
  `retro install redhat/3.0.3-infomagic`.
- **Red Hat Linux 4.2 “Biltmore”** is a widely remembered classic and a fine
  example of the Linux 2.0 era. Try `retro install redhat/4.2-infomagic`.

### The desktop years: 1998–1999

- **Slackware 3.5** captures the late peak of classic libc 5 Slackware, with
  Linux 2.0 and XFree86 3.3. Try `retro install slackware/3.5/kimmel`.
- **Red Hat Linux 5.1 “Manhattan”** shows the transition toward mainstream
  Linux: glibc, a fuller desktop, and a more polished installer. Try
  `retro install redhat/5.1-infomagic`.
- **Slackware 4.0** finishes the tour with KDE 1.1.1 on Linux 2.2—an early look
  at the integrated desktop era that followed classic X11 window managers.
  Try `retro install slackware/4.0-walnut`.

The variant names—Walnut Creek, InfoMagic, Kimmel, and others—identify the
historical disc or archive the recipe uses. Sometimes the same distro release
appeared in several collections, each with its own surrounding software and
small media differences.

## Browse the Collection

- [Slackware](slackware/README.md) spans 1993 through 2003, from Linux 0.99 to
  the 2.4 kernel era.
- [Debian](debian/README.md) covers 0.91 and the Buzz, Rex, and Bo releases.
- [Red Hat Linux](redhat/README.md) runs from the early pre-RHEL releases
  through Red Hat Linux 6.1.
- [CD-ROM collections](cdrom) preserve complete period discs, including the
  FTP snapshots, utilities, source trees, and assorted curiosities shipped
  alongside Linux distributions.

These are genuinely old operating systems. Expect rough edges, unfamiliar
installers, and the occasional historical bug. They are also insecure by
modern standards: do not put sensitive information in a guest or expose its
services publicly. retrodist uses QEMU's isolated user-mode networking by
default.

## More Documentation

- [USAGE.md](USAGE.md): commands, VM controls, networking, and moving files.
- [ARCHITECTURE.md](ARCHITECTURE.md): how the host, QEMU, and old guest systems
  fit together.
- [CONTRIBUTING.md](CONTRIBUTING.md): adding or maintaining distro recipes.
- [guestlib/README.md](guestlib/README.md): the portable runtime used inside
  old installers and installed systems.

## Credits

- [QEMU Advent Calendar](https://www.qemu-advent-calendar.org/2014/) for giving
  me the idea to start playing with this. Slackware 1.0 is Day 1 from 2014.
- [Archive.org](https://archive.org/) for keeping around old CD-ROM and floppy
  images of distros gone by.

## License

Copyright 2022, 2026 J.B. Langston

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to use,
copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
