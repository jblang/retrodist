Red Hat Linux 3.0.3
===================

The contents of this CD-ROM are Copyright (C) 1996 Red Hat Software, Inc.
and others.  Please see the individual copyright notices in each source
package for distribution terms.  The distribution terms of the tools
copyrighted by Red Hat Software are as noted in the file COPYING.

Red Hat, RPM, and glint are trademarks of Red Hat Software, Inc.

============================================================================
CD ORGANIZATION

This directory is organized as follows:

/mnt/redhat
  |----> RedHat
           |----> RPMS         -- binary packages  
           |----> SRPMS        -- source packages  
           |----> base         -- small filesystem setup archives
           |----> instimage    -- image used for graphical installs
           |----> sets         -- symlinks to rpms, divided by series
  |----> trees                 -- filesystems used for boot and ramdisks
  |----> images                -- boot and ramdisk images
           |----> floppies     -- floppy disk images for floppy install
  |----> dosutils              -- installation utilities for DOS
  |----> doc                   -- various FAQs and HOWTOs
  |----> COPYING	       -- copyright information
  |----> README		       -- this file
  |----> RPM-PGP-KEY	       -- PGP signature for packages from Red Hat
  |----> redhat.exe	       -- DOS program for zero floppy installs
  |----> upgrade	       -- upgrade script for Red Hat 2.x based systems

The following directories are used during system installation and should
be ignored:

    bin    bootdisk cdrom    dev      doc   dosutils    etc    floppy  lib
    image  mnt      proc     ramdisk  sbin  tmp         usr    var

If you are mirroring to a partition or an NFS volume, you'll need to
get everything under RedHat, as well as the disk images from images
that you need for your system.

============================================================================
UPGRADING FROM A PREVIOUS RED HAT LINUX RELEASE

To upgrade to Red Hat Linux 3.0.3 from a previous Red Hat Linux 2.x, run
the upgrade script in the current directory with the command

./upgrade

(you must have perl installed to do this). If you'd like to see what
will be upgraded before performing the actual installation, run

./upgrade --test

If you are upgrading from any Red Hat release prior to 2.0, you must
reinstall your system.

It is probably a good idea to quit as many applications as possible
before running the upgrade script.  You may even want to bring your
system down to single user mode with `telinit 1'.  After the upgrade
you can return to multi-user mode with `/sbin/telinit 3'.

A log file of the upgrade is created in /tmp/upgradelog.

============================================================================
UPGRADING CALDERA NETWORK DESKTOP TO RED HAT LINUX 3.0.3

There are no special instructions for upgrading CND.  Just use the
upgrade script as described above.

============================================================================
QUICK INSTALLATION

First select a boot image from images/1213/image.txt and write it to a
floppy using `dd' (or `dosutils\rawrite.exe' on DOS).  You also need to
make two ramdisk floppies from images/ramdisk1.img and images/ramdisk2.img.
Note that PCMCIA support is included and will work with any of the boot
disks you use. [Also Note:  If you use a PCMCIA SCSI card you need to
use boot image with "Adaptec" support.]

The images in images/1213/image.txt are listed with supported devices:
	o SCSI Support
	o Ethernet Support
	o CD-ROM Support
Find the image that best matches your system.

If you are already running Linux, use the mkfloppies.pl script in the
images directory to do this automatically.  It will also save important
system information for later use.

After creating the three floppies, insert the boot floppy and reboot your
computer.  Follow the on-line instructions to install your Red Hat system.

If you are installing from a CD, you only need to create a single boot
floppy - you don't need the ram disks. Follow the instructions for a 
"Single Floppy Boot" after booting the boot disk.

============================================================================
LINUX DOCUMENTATION

The 'doc' directory contains lots of useful information on linux.
There is also an HTML directory with lots of that documentation in
html format.  If you have a DOS or Windows WWW browser, you can point
it at the following files on the CD-ROM:

    doc/HTML/index.html
    doc/HTML/ldp/HOWTO-INDEX.html 
    doc/HTML/ldp/install-guide-2.2.2.html/gs.html

There is a mailing list for discussion of Red Hat Linux. To subscribe,
send mail to redhat-list-request@redhat.com with "subscribe" in the subject.

============================================================================
RED HAT LINUX MANUAL

If you did not receive documentation with this product, you can order the
manual from the Red Hat Software.

Red Hat Software can be reached at:

phone: (203) 454-5500
       (800) 454-5502
  fax: (203) 454-2582
email: info@redhat.com
  FTP: ftp://ftp.redhat.com
  WWW: http://www.redhat.com

Red Hat Software
25 Sylvan Road
Westport, CT 06880
USA
