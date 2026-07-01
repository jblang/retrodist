Red Hat Linux/Intel 4.1 Vanderbilt
==================================

The contents of this CD-ROM are Copyright (C) 1997 Red Hat Software, Inc.
and others.  Please see the individual copyright notices in each source
package for distribution terms.  The distribution terms of the tools
copyrighted by Red Hat Software are as noted in the file COPYING.

Red Hat, RPM, Red Baron, and glint are trademarks of Red Hat Software, Inc.

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

If you are installing this release via ftp, off of a hard drive, or through
a PCMCIA card, you need both a boot disk and a supplemental disk. If you are
installing via NFS or CDROM without using a PCMCIA adapter you only need
a boot disk. If you did not receive floppy disks with this product, the 
images for these disks are in the images directory. Either the rawrite program
in the dosutils directory or 'dd' under any Unix like system can be used
to transfer the image to physical floppies. Once the diskettes are made,
insert the boot disk and boot your machine. 

============================================================================
RED HAT LINUX MANUAL

If you did not receive documentation with this product, you can order the
manual from the Red Hat Software.

Red Hat Software can be reached at:

phone: (919) 572-6500
       (800) 454-5502
       (888) RED-HAT1
  fax: (919) 572-6726
email: info@redhat.com
  FTP: ftp://ftp.redhat.com
  WWW: http://www.redhat.com

Red Hat Software
3203 Yorktown Avenue Suite 123
Durham, NC  27713
USA
