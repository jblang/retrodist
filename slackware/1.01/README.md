# Slackware 1.01

Patrick Volkerding [announced](ANNOUNCE.txt) Slackware 1.01 in `comp.os.linux.announce` on August 4, 1993. This version still uses the SLS doinstall/sysinstall scripts.

## Variants

### official

The version on the [official mirror](https://mirrors.slackware.com/slackware/slackware-1.01/) includes the complete `a` series but is missing the entire `x` series except `x10`.

### channel1

[grem75](https://archive.org/details/@grem75) uploaded [slackware-101](https://archive.org/details/slackware-101) to archive.org in July 2021, which includes the complete `x1-x11` series.  The files on the `a1-a13` and `x10` disks are identical to those found on the official mirror.

Some files apparently got accidentally copied from the `a` series to the `x` series and vice versa, so the extract script removes them.

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

### official+sls

[chitaotao](https://archive.org/details/@chitaotao) uploaded [slackware101](https://archive.org/details/slackware101) to archive.org in December 2021.  This `official+sls` variant contains floppy images for the complete `a1-a13`, `t1-t3`, and `x1-x10` series as well as a hard drive image for an installed system.

The files in the `a` series are identical to those from the official mirror, except that `a10` is missing `smail.tgz`.  However, the files from the `x` and `t` series are actually those from SLS 1.03.
