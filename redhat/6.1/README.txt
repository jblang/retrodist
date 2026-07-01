Red Hat Linux/Intel 6.1 (Cartman)
=================================

The contents of this CD-ROM are Copyright (C) 1999 Red Hat, Inc. and others.  
Please see the individual copyright notices in each source package for 
distribution terms.  The distribution terms of the tools copyrighted by 
Red Hat, Inc. are as noted in the file COPYING.

Red Hat and RPM are trademarks of Red Hat, Inc.

============================================================================
DIRECTORY ORGANIZATION

This directory is organized as follows:

/mnt/redhat
  |----> RedHat
           |----> RPMS         -- binary packages  
           |----> base         -- small filesystem setup archives
           |----> instimage    -- image used for installs
  |----> images                -- boot and ramdisk images
  |----> dosutils              -- installation utilities for DOS
  |----> doc                   -- various FAQs and HOWTOs
  |----> misc                  -- source code for installation process
  |----> COPYING	       -- copyright information
  |----> README		       -- this file
  |----> RPM-GPG-KEY	       -- GPG signature for packages from Red Hat

If you are mirroring to a partition or an NFS volume, you'll need to
get everything under RedHat, as well as the disk images from images
that you need for your system.

============================================================================
INSTALLING

There are three separate boot images for booting your system; you will
need one of them to boot your system into the Red Hat installation and
upgrade process.  For CDROM and hard drive installs, use the boot.img
file (most Red Hat boxed sets include this floppy already; just boot
it!). NFS, ftp, and http installations requires the bootnet.img floppy,
which is available in the images directory. Installs through PCMCIA adapters
(such as for PCMCIA CDROM or networking cards) need the pcmcia.img floppy.

If you did not receive the necessary floppy disks with this product, the
images for these disks are in the images directory. Either the rawrite
program in the dosutils directory or 'dd' under any Unix like system can
be used to transfer the image to physical floppies. Once the diskette
has been made, insert the boot disk and boot your machine.

Many computers can now automatically boot from CDROMs. If you have one and
it is properly configured, you can boot the Red Hat Linux CDROM directly
without using any floppy disks. After booting, you'll be able to install
your system from the CDROM.

============================================================================
SUPPORT

For those that have web access, see http://www.redhat.com.  In particular,
access to our mailing lists can be found at:

	http://www.redhat.com/mailing-lists

If you don't have web access you can still subscribe to the main mailing
list.  To subscribe, send mail to cartman-list-request@redhat.com with

subscribe

in the subject line.  You can leave the body empty.

============================================================================
RED HAT LINUX MANUAL

If you did not receive documentation with this product, you can order the
manual from the Red Hat, Inc.

Red Hat, Inc. can be reached at:

	(800) 454-5502
	(888) RED-HAT1
	(919) 547-0012
fax: 	(919) 547-0024
email: 	info@redhat.com
FTP: 	ftp://ftp.redhat.com
WWW: 	http://www.redhat.com

Red Hat, Inc.
PO Box 13588
Research Triangle Park, NC
27713
