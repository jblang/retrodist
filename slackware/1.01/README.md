# Slackware 1.01

Patrick Volkerding [announced](ANNOUNCE.txt) Slackware 1.01 in `comp.os.linux.announce` on August 4, 1993. 

## Variants

### official

The version on the [official mirror](https://mirrors.slackware.com/slackware/slackware-1.01/) includes the complete `a` series but is missing the entire `x` series except `x10`.

### grem75

[grem75](https://archive.org/details/slackware-101) uploaded a version to archive.org in July 2021 that includes the complete `x1-x11` series.  The files on the `a1-a13` and `x10` disks are identical to those found on the official mirror.

Some files apparently got accidentally copied from the `a` series to the `x` series and vice versa, so the extract script moves the extra files from the `a` series to `aNb` directories and those for the `x` series to `xNb` directories. I have verified the files in the `aNb` and `xNb` directories are identical to those in the corresponding `aN` and `xN` directory, so they are not needed.

When the zips in the `a1` directory are extracted, they display an ad for the Channel 1 BBS, so I'm assuming that's where these files originated.

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

[chitaotao](https://archive.org/details/slackware101) uploaded another version to archive.org in December 2021.  The archive contains floppy images for the complete `a1-a13`, `t1-t3`, and `x1-x10` series as well as a hard drive image for an installed system.  

The files in the `a` series are identical to those from the official mirror, except that `a10` is missing `smail.tgz`.  However, the files from the `x` and `t` series are actually those from SLS 1.03.

## Automatic Installation

Automatic installation is supported (and recommended) for 1.0x and 1.1.x versions.

- Log in as `root` when prompted. Ignore the rest of the instructions.
- Run the automatic installer: `/autoinst.sh`.
- Marvel as cryptic text scrolls by much faster than it would have on a real PC in 1993. When the installation is done, the VM will reboot.
- The scripts will configure your system and then reboot again.
- Log in as `root` once again. You've now got a fully-loaded Slackware 1.01 system, with properly configured X, networking, and serial console. Have fun! :^)

## Manual Installation

If you really want the authentic 1993 Slackware installation experience...

- *Carefully* read the instructions printed out before the login prompt. 
- If you need more guidance on partitioning, run `install.info` after logging in.
- Partition your disk, initialize the swap, and format the root partition.
- Run `doinstall /dev/hda2` (or your root partition). Answer the questions when prompted. 
- Once you get to the following prompts, enter the responses in bold:
  - Where will you be installing Linux from? **2**
  - Enter the partition that the source is on (eg. /dev/hda1): **/dev/hdb1** 
  - Enter the type of filesystem (minix/ext2/msdos) **msdos**
- Be prepared to answer y/n approximately 100 times about whether you want to install each individual package. 