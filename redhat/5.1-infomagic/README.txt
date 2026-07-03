Red Hat Linux/Intel 5.1 (Manhattan)
===================================

The contents of this CD-ROM are Copyright (C) 1998 Red Hat Software, Inc.
and others.  Please see the individual copyright notices in each source
package for distribution terms.  The distribution terms of the tools
copyrighted by Red Hat Software are as noted in the file COPYING.

Red Hat, RPM, and glint are trademarks of Red Hat Software, Inc.

============================================================================
DIRECTORY ORGANIZATION

This directory is organized as follows:

/mnt/redhat
  |----> RedHat
           |----> RPMS         -- binary packages  
           |----> base         -- small filesystem setup archives
           |----> instimage    -- image used for graphical installs
  |----> images                -- boot and ramdisk images
  |----> dosutils              -- installation utilities for DOS
  |----> doc                   -- various FAQs and HOWTOs
  |----> misc                  -- source files, install trees
  |----> live                  -- live filesystem
  |----> COPYING	       -- copyright information
  |----> README		       -- this file
  |----> RPM-PGP-KEY	       -- PGP signature for packages from Red Hat

If you are mirroring to a partition or an NFS volume, you'll need to
get everything under RedHat, as well as the disk images from images
that you need for your system.

============================================================================
INSTALLING

If you are installing this release via ftp, off of a hard drive, or
through a PCMCIA card, you need both a boot disk and a supplemental
disk. If you are installing via NFS or CDROM without using a PCMCIA
adapter you only need a boot disk. If you did not receive floppy
disks with this product, the images for these disks are in the images
directory. Either the rawrite program in the dosutils directory or 'dd'
under any Unix like system can be used to transfer the image to physical
floppies. Once the diskettes are made, insert the boot disk and boot
your machine.

============================================================================
SUPPORT

For those that have web access, see http://www.redhat.com.  In particular,
access to our mailing lists can be found at:

	http://www.redhat.com/mailing-lists

If you don't have web access you can still subscribe to the main mailing
list.  To subscribe, send mail to manhattan-list-request@redhat.com with

subscribe

in the subject line.  You can leave the body empty.

============================================================================
RED HAT LINUX MANUAL

If you did not receive documentation with this product, you can order the
manual from the Red Hat Software.

Red Hat Software can be reached at:

	(800) 454-5502
	(888) RED-HAT1
	(919) 547-0012
fax: 	(919) 547-0024
email: 	info@redhat.com
FTP: 	ftp://ftp.redhat.com
WWW: 	http://www.redhat.com

Red Hat Software
4201 Research Commons Suite 100
79 T.W. Alexander Drive
PO Box 13588
Research Triangle Park, NC
27709
