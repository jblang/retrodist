Red Hat Commercial Linux
Mother's Day + 0.1 Release 1995

The contents of this CD-ROM are Copyright (C) 1995 Red Hat Software
and others.  Please see the individual copyright notices in each source
package for distribution terms.  The distribution terms of the tools
copyrighted by Red Hat Software are as noted in the file COPYING.

The docs subdirectory contains lots of information.  The answers to
most of your questions are probably in there somewhere!  Please see
http://www.redhat.com/ and/or ftp://ftp.redhat.com/ for the latest
information, installation tips, new packages, etc.

CD ORGANIZATION

This CD is organized thusly:

/mnt/rhscd
  |----> bin                       -- binaries used during install
  |----> bootfs                    -- (tiny) filesystem used for boot disks
  |----> bootstrap                 -- the bootstrap filesystem
  |----> config                    -- config files used during installation
  |----> doc                       -- documentation
         |----> FAQHOWTO           -- HOWTOs and Frequently Asked Questions
         |----> XFree86            -- XFree86 random documentation
  |----> dos                       -- useful DOS programs (rawrite, etc)
  |----> images                    -- boot and root disk images, kernels
  |----> instpar                   -- filesystem used to create root disk
  |----> rescue                    -- filesystem used to create rescue disk
  |----> lost+found                -- ext2fs special directory
  |----> rpps                      -- all the RHS rpps and series files
  |----> prep                      -- archive of prep.ai.mit.edu

The second CD is a snapshot of the sunsite.unc.edu FTP archives.  This
archive contains numerous sources and binaries not included in RPP format
on this CD.  Read the accompanying documentation for each package before
installing it to make sure you don't overwrite anything.

BOOT AND ROOT DISKS

The disk images are in the images directory.  The root disk image is
rootdisk.img, and the various boot disk images are under directories
according to kernel version.  In each kernel version directory is a
image.idx file which describes each boot disk kernel configuration.
The fields are: image number; SCSI; Ethernet; CD-ROM.

If you're creating the floppies from a Unix box that has both dd and perl
available, running "perl mkfloppies.pl" in the images directory should
help get you started.

The images/rescue.img is a "emergency root disk" image.  You can use
it in conjunction with your boot disk to recover from system damage.

BUILDING YOUR OWN BOOT DISKS

If you have access to an existing Linux machine, you can build your
own boot disks for Red Hat Commercial Linux using any kernel you wish.
Read the README in the bootfs directory for instructions.

Red Hat Software
PO Box 4325
Chapel Hill, NC 27515
