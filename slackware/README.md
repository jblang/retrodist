# Slackware

[Slackware](http://www.slackware.com/), first released in July 1993 by Patrick Volkerding, is the oldest Linux distro still maintained.  

## Installation

For Slackware `1.0beta` and `1.01`, use the version-specific instructions:

- [Slackware pre-1.0 beta](./1.0beta/README.md#installation)
- [Slackware 1.01](./1.01/README.md#automatic-installation)

For Slackware `1.1.1` and later in this repo, the install flow is mostly the same:

1. Boot the VM normally.
2. If the boot process asks for the root disk, switch `floppy0` to the staged `root.img` from the QEMU monitor by pressing `C-a c` in the terminal and entering:

```text
change floppy0 root.img
```

3. If you had to swap the root disk, press `Enter` at the prompt, ignore the misleading floppy I/O error if it appears, and press `Enter` again until you reach a login prompt.
4. Log in as `root` when the system presents a login prompt.
5. Ignore the stock installer prompts and run the staged autoinstall script from the DOS partition:

```sh
mount -t msdos /dev/hdb1 /var/adm/mount
/var/adm/mount/autoinst
```

After the installer and post-install configuration finish, the VM will reboot into the installed system.

If you want the original manual install flow instead, use the boot/root environment to partition the disk, initialize swap, format the root partition, and run the stock installer from the staged MSDOS partition on `/dev/hdb1`.

## Milestones

Version 1.0 started out as a collection of patches and new packages for the Softlanding Linux System (SLS). It used the same `doinstall`/`sysinstall` scripts and SLS packages could be installed directly.

Version 1.1 saw the install and package management scripts rewritten at the request of SLS author Peter MacDonald, who objected to other distributions using them. The `setup` script replaced `doinstall` and `pkgtool` replaced `sysinstall`. 1.1.2 introduced the color `dialog`-based scripts that are still used by Slackware today.

## Historical Background

- [Wikipedia article](https://en.wikipedia.org/wiki/Slackware)
- A History of Slackware Devlopment by Eric Hamleers (aka alienbob)
  - [Video](https://www.youtube.com/watch?v=Xh2eah5L4b8)
  - [Slides](http://www.slackware.com/~alien/tdose2009/t-dose-slackware.pdf)
- Interviews with Patrick Volkerding:
  - [1994](https://www.linuxjournal.com/article/2750) by Linux Journal
  - [2012](https://www.linuxquestions.org/questions/interviews-28/interview-with-patrick-volkerding-of-slackware-949029/) by LinuxQuestions.org
