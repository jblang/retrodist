		     Welcome to the March Edition
				of the
	     InfoMagic Linux Developer's Resource CD-ROM
			    23 March 1995

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Slackware 2.2.0

Kernel sources up to version 1.2.1.

XFree86 3.1.1 integrated into Slackware.  XFree86 2.1, 2.1.1 and 3.1
are also included.

The WordPerfect SCO demo which runs with the Linux iBSC package.

A demo of FlagShip, an application generator for Linux, like Clipper
under DOS.  This was made available by Mark Bolzern.

A demo of "zbbs" from Maple Leaf Software.

A demo of Executor, a MAC emulator for Linux.

A live image of a full Slackware 2.2.0 installation that may be used to
run directly from the CD via symbolic links.  This option is fully
supported by the Slackware setup utility.  Thanks to Patrick for
making this available to everyone.

The full Slackware 2.2.0 source tree.

The "mini-linux" distribution that allows a Linux "Test Drive" from
an existing DOS partition.


General Information about the Linux Developer's Resource
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
These discs are published every two months (or so) and include
snapshots of the TSX-11.MIT.EDU and Sunsite.UNC.EDU linux archives.
As with previous editions we have included the complete GNU archive from
prep.ai.mit.edu so as to be in full compliance with the GNU Public
License, a copy of which is provided in the "gnu" directory.

The following are mirrored directly from their home sites:
	Slackware
	wine
	Kernel Sources
	sunacm (Networking Code)
	bogus distribution
	Flagship
	GNU sources
	JE & JF
	and (naturally) sunsite and TSX.

See the RoadMap at the end of this file for the layout of the 4-CDs.

These discs are mastered in ISO-9660 format with Rock Ridge extensions
to preserve the long mixed case filenames and deeply nested directory
structure.

A few large packages common to TSX-11 & SuNSITE have been merged and
put into top level directories.  This includes the kernel distributions
and XFree86.

Some popular packages have been removed due to copyright
restrictions, these include: Mosaic, Netscape, kermit, getty_ps, xv,
and Chimera.  We applogize for the inconvenience.  These (and more)
can of course be found on our FTP server, ftp.infomagic.com
(165.113.211.2).

The following files are included with the permission of their authors:

SCSI HowTo	(Drew Eckhardt)
ncftp		(Mike Gleason)


If you find anything on these CD's that should not be distributed
commercially, please notify us so we can contact the authors for
permission or remove them from future releases.  We are careful to
remove everything we know about, but with over 2GB of material it is
quite possible we have overlooked something.

The HowTo docs have been pulled out and put into a directory directly
off the root of disc 1.  The HowTo material is also provided in the
form of a Microsoft Multimedia Viewer title (along with the Viewer
software) for browsing/searching under Microsoft Windows.  The Viewer
supports both hypertext access to all the HowTo's and full-text
search.  You may search for single words or phrases and find all
occurrences in any of the documents.  It will present a list of topics
in which your search phrase was found as well as highlighting the text
in each topic.

We have provided a setup program for the Viewer software and HowTo
docs, select "File/Run" from the program manager and run
X:\viewer\setup.exe (where X is your CD-ROM drive letter).  The viewer
may also be run directly from the CD.  From the Program Manager of
Windows, select "File/Run" and type in the following command:

	X:\viewer\mviewer2 HowTo.MVB

where "X" is the letter corresponding to your CD-ROM.

Included distributions and their versions are shown below.

Slackware	2.2.0
SLS		1.0.6
JE		Latest version from September
MCC		1.0+
Debian		0.91 and 0.93
bogus		1.0.1

In the directory "lininst" on Disc 1, is a Microsoft Windows based
installation utility that will assist you in selecting the correct
boot kernel based on your hardware.  It will create the boot & root
diskettes for Slackware within Windows.  It also detects your CD
drives and floppy drives.  It may be run directly from the CD, or
copied to the hard disk.  If for some reason it does not correctly
detect your CD, you may invoke it with the drive letter on the
command line to override the automatic CD detection.

SLACKWARE 2.2.0 Notes:
~~~~~~~~~~~~~~~~~~~~~~

Due to changes in the Slackware setup, the distribution now appears
directly off the root of Disc 1.  The installation sets are in the
directory "slakware" to match the expectations of the setup utility.
The directories "slaktest" and "link2cd" are used for CD dependant
installs as explained in the Slackware setup screens.

The Boot & Root disks are in the directory "slakinst" to make them
easier to find under DOS (where long file names are not allowed :-).
Please refer to the installation notes in the "slakware" directory
before proceeding.  Contributed software is in the directory
"slakinst/contrib" on disc 1.

The complete source tree is in "Slackware_Source" also on Disc 1.
This tree contains a set of scripts to build either the entire tree
of any part of it.  These scripts are called SlackBuild.


Notes for NewComers
~~~~~~~~~~~~~~~~~~~
In the "howto" subdirectory of disc 1, there are a series of
HOWTO documents that provide detailed instructions on how to configure
and install nearly every aspect of Linux.  Please refer to these
before starting if you have never done it before !  There is some
additional material in the "guide" directory of disc 1.  These documents
are in UNIX(tm) format which means they do not end in CRLF, only LF
and will therefore not print on most DOS systems.  You will need to
view them with an editor or word processor (or use the included
Multimedia Viewer software).

The easiest distribution to use seems to be Slackware.  Please refer
to the material in the "slakinst" directory on disc 1 for help in
getting started.

The tools used to create the bootable floppies, for all the
distributions, are in the directory "dos_util" on disc 1.  This
directory also contains a number of partition manipulation utilities
including one called "fips" that can be used to resize DOS partitions
without damaging them.  Please read the file "fips09.doc" before using
it.

The "boot" and "root" images have been uncompressed, so you may ignore
the mention of "gzip" in the install notes.


Additional Information
~~~~~~~~~~~~~~~~~~~~~~
The file "00_find" contains the result of the command:
"find . -type f -print" from the root of both discs.

Technical Support
~~~~~~~~~~~~~~~~~
InfoMagic is pleased to provide as much technical support as we can.
Please do not hesitate to either email, FAX, or phone us with any
questions on installation, hardware compatibility, or any other
problem.  If we don't know the answer we will try to find it for you !

email:	support@InfoMagic.com
Tel:	520-526-9852 (Tech Support)
	520-526-9565 (Orders) 800-800-6613 (Within the US and Canada)
	404-371-0291
FAX:	520-526-9573

For support in the UK and Europe, you may contact:

Lasermoon, Ltd.
2a Beaconsfield Toad
Fareham, Hants, England. PO16 0QB
Tel:	+44 (0) 329 826444
Fax:	+44 (0) 329 825936
Email:	info@lasermoon.co.uk


Enjoy Linux, and check out our other CD's in the file "catalog.txt"


RoadMap
~~~~~~~
disc1/slakware			Installation disk sets
disc1/slakinst			Boot/Root disk images
disc1/Slackware_Source		Source tree for everything in Slackware
disc1/link2cd			Slackware Packages to "run" off the CD.
disc1/slaktest			Alternate version of CD dependant install.
disc1/minilin				A UMSDOS based install in 4 floppy
				sized pieces.  Copy to your hard disk
				under DOS, unzip and boot immediately
				into Linux !
disc1/HOWTO				Linux HowTo docs
disc1/guides				Linux Installation, Network
				Administrator, System Admin, and
				Kernel Hackers "guides"
disc1/help			Assorted InfoMagic supplied files
				referenced in the Quickstart Guide
disc1/viewer			HowTo docs in Microsoft Windows
				Viewer format
disc1/dos_util			Utilities to create boot floppies
disc1/demos			Demos of WordPerfect, FlagShip, zBBS,
				Executor (MAC emulator) and Cockpit.
disc1/lininst			Microsoft Windows based Install Disk Builder.

disc2/sunsite			Archive from sunsite.unc.edu
disc2/MCC			The venerable MCC 1.0+ distribution

disc3/tsx-11			Archive from tsx-11.mit.edu
disc3/kernel			Kernel sources up to 1.2.1
disc3/wine			Windows Emulator archive
disc3/Oberon			Oberon System for Linux
disc3/Scheme			MIT Scheme
disc3/sunacm			Alan Cox's networking code and utilities

disc4/XFree86			Versions 2.1, 2.1.1, 3.1, and 3.1.1
				Binaries only.
disc4/bogus			Bogus version 1.0.1
disc4/debian			Debian release 0.93R5
disc4/JE			Japanese Extensions
disc4/JF			Japanese HowTo's
disc4/gnu			GNU archive from prep.ai.mit.edu

The following people have provided help and advice in the preparation
of these CD's:

Stacey Brewer (slb@infomagic.com)
Mark Horton (mah@ka4ybr.atl.ga.us)
Fred van Kempen (waltje@infomagic.com)

