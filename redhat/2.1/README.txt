Red Hat Linux 2.1
=================

The contents of this CD-ROM are Copyright (C) 1995 Red Hat Software, Inc.
and others.  Please see the individual copyright notices in each source
package for distribution terms.  The distribution terms of the tools
copyrighted by Red Hat Software are as noted in the file COPYING.

Red Hat, rpm, and glint are trademarks of Red Hat Software, Inc.

============================================================================
CD ORGANIZATION

This directory is organized thusly:

/mnt/redhat
  |----> RedHat
           |----> RPMS             -- binary packages  
           |----> SRPMS            -- source packages  
           |----> base             -- small filesystem setup archives
           |----> instimage        -- image used for graphical installs
           |----> sets             -- symlinks to rpms, divided by series
  |----> trees                     -- filesystems used for boot and ramdisks
  |----> images                    -- boot and ramdisk images
           |----> floppies         -- floppy disk images for floppy install
  |----> dosutils                  -- installation utilities for DOS
  |----> doc                       -- various FAQs and HOWTOs

If you are mirroring to a partition or an NFS volume, you'll need to
get everything under RedHat, as well as the disk images from images
that you need for your system.

============================================================================
UPGRADING FROM A PREVIOUS RED HAT LINUX RELEASE

To upgrade to Red Hat Linux 2.1 from Red Hat Commercial Linux 2.0, run
the upgrade script in the current directory with the command

./upgrade

(you must have perl installed to do this). If you'd like to see what
will be upgraded before performing the actual installation, run

./upgrade --test

If you are upgrading from any other Red Hat release, you must reinstall
your system.

It is probably a good idea to quit as many applications as possible
before running the upgrade script.  You may even want to bring your
system down to single user mode with `telinit 1'.  After the upgrade
you can return to multi-user mode with `/sbin/telinit 3'.

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

============================================================================
LINUX DOCUMENTATION

The 'doc' directory contains lots of useful information on linux.
There is also an HTML directory with lots of that documentation in
html format.  If you have a DOS or Windows WWW browser, you can point
them on the CD-ROM in:

doc/HTML/index.html
doc/HTML/ldp/HOWTO-INDEX.html 
doc/HTML/ldp/install-guide-2.2.2.html/gs.html

There is a mailing list for discussion of this Red Hat release. To subscribe,
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
Suite 113
3201 Yorktown Road
Durham, NC 27713
