# Slackware 1.01

Patrick Volkerding [announced](ANNOUNCE.txt) Slackware 1.01 in `comp.os.linux.announce` on August 4, 1993. 

## Variants

### official

The version on the [official mirror](https://mirrors.slackware.com/slackware/slackware-1.01/) includes the complete `a` series but is missing the entire `x` series except `x10`.

### grem75

[grem75](https://archive.org/details/slackware-101) uploaded a complete version to archive.org in July 2021.  The files on the `a1-a13` and `x9` disks are identical to those found on the official mirror. The complete `x1-x11` series is included.

Some files apparently got accidentally copied from the `a` series to the `x` series and vice versa, so the extract script moves the extra files from the `a` series to `aNb` directories and those for the `x` series to `xNb` directories. I have verified the files in the `aNb` and `xNb` directories are identical to those in the corresponding `aN` and `xN` directory.

The files in the `a1` directory are zipped, unlike on the official mirror. When those zips are extracted, they display an ad for the Channel 1 BBS, so I'm assuming that's where these files originated.

```
         #### #  # #### #### #### #### #     ##
         #    #### #### #  # #  # ##   #      #
         #### #  # #  # #  # #  # #### ####   #
     ####[ Hi-Performance Telecommunications & Information Services ]###
     #  CHANNEL 1 (R) * Cambridge MA * 617 354-7077 * Internet/Usenet  #
     #  85 Lines * 12Gigs * IBM/Amiga/Mac/Unix * Best Files in the USA #
     ########[ Call for latest updates * V.32bis: 617 354-3230 ]########
```

### chitaotao

[chitaotao](https://archive.org/details/slackware101) uploaded another version to archive.org in December 2021 with the description:

> A much more complete disck set of  slackware 1.01. The 7z file is from slackware mirror (containing a1-a11, x10) the zip file contains a1-a11, x1-x11, t1-t3. 

The archive contains floppy images for the complete `a1-a13`, `t1-t3`, and `x1-x10` series as well as a QEMU image for an installed system.  The files in the `a` series are indeed identical to those from the official mirror, except that `a10` is missing `smail.tgz`.  However, the files from the `x` series are identical to those from SLS 1.03, as are files in the `t` except for `texpk.tgz`.

## Installation

For installation, you have two options...

### Manual

If you want the authentic 1993 Slackware installation experience, carefully read the instructions printed out before the login prompt. If you need more guidance on partitioning, run `install.info` after logging in. Once you get to the following prompts in the `doinstall` script, enter the responses in bold:

- Where will you be installing Linux from? **2**
- Enter the partition that the source is on (eg. /dev/hda1): **/dev/hdb1** 
- Enter the type of filesystem (minix/ext2/msdos) **msdos**

I'm not going to spoil your "fun" by offering any further hints.  If you want an easier way, use my automatic script instead.

### Automatic

1. Log in as `root` when prompted. Ignore the rest of the instructions.
2. Mount the installation source: `mount -t msdos /dev/hdb1 /mnt`
3. Run the automatic installer: `/mnt/autoinst.sh`.
4. Marvel as cryptic text scrolls by much faster than it would have on a real PC in 1993. When the installation is done, the VM will reboot.
5. Log in as `root` once again. You've now got a fully-loaded Slackware 1.01 system. Have fun! :^)

The `autoinst.sh` file will automatically partition a 500MB disk on `/dev/hda` and install the complete set of packages from a DOS partition on `/dev/hdb1`. It also configures X11 to work in QEMU, enables a serial console on `ttyS0`, and configures `eth0` with the IP address `10.0.2.101`.  The network and serial configuration came from the [QEMU Advent Calendar](https://www.qemu-advent-calendar.org/2014/).