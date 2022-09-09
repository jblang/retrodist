			    Welcome to the
	     InfoMagic Linux Developer's Resource CD-ROM
			     August 1995

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Slackware 2.3.0 and ELF Beta

Additional Slackware boot image with AHA2940 support and Phillips
LMS206 CD support.  Installable kernel provided for AHA2940 in the
Slackware "Q" series.

RedHat Mother's Day + 0.1 release

Kernel sources up to version 1.2.13 and 1.3.15

XFree86 3.1.1 integrated into Slackware.  XFree86 3.1.2 is also included

A fully functional demo of Pathfinder (usable until the end of
September).  This is a visual source code browser for C/C++, Tcl and
iTcl.  It also includes the "Open Desktop Graphical Frontend" for
relational databases.

A demo of dBMAN from Versasoft.  dBMAN is a comprehensive relational
database managment program.  It includes tools for: Information
Management, Program Development and Report Printing.

UNIX Cockpit, an X11 filemanager.

A demo of SmartWare PLUS from ANGOSS Software.  SmartWare PLUS is a
cross-platform integrated product suite that includes: Relational
Database, Spreadsheet w/Presentation Graphics, WordProcessor, and
Communications.  Keys to enable the demo for personal or commercial
use are available from InfoMagic.

The GPM (Garden Point Modula) Modula-2 and Oberon compilers for Linux.

The WordPerfect SCO demo which runs with the Linux iBSC package.

A demo of FlagShip, an application generator for Linux, like Clipper
under DOS.  This was made available by Mark Bolzern.

A demo of "zbbs" from Maple Leaf Software.

GPPLINUX, a demo of an Object Oriented development environment for Linux.

The /usr tree of a Slackware 2.3.0 installation which may used to run
most packages from the CD.  This is an option in the Slackware setup.

The full Slackware 2.3.0 source tree.

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
	Flagship
	GNU sources
	JE & JF
	and (naturally) sunsite and TSX.

Other packages have been provided to us by their authors.

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

RedHat		Mother's Day + 0.1
Slackware	2.3.0
JE		Latest version from September

In the directory "lininst" on Disc 1, is a Microsoft Windows based
installation utility that will assist you in selecting the correct
boot kernel based on your hardware.  It will create the boot & root
diskettes for Slackware within Windows.  It also detects your CD
drives and floppy drives.  It may be run directly from the CD, or
copied to the hard disk.  If for some reason it does not correctly
detect your CD, you may invoke it with the drive letter on the
command line to override the automatic CD detection.

SLACKWARE 2.3.0 Notes:
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

The RedHat distribution is now included in the CD set and may be
easier to install than Slackware.  Please refer to the file
"redhat.rme" in the root directory of Disc 1 for instructions on
installing this distribution.

For help with installing Slackware, refer to the files in the
"slakinst" directory of Disc 1.

The tools used to create the bootable floppies, for all the
distributions, are in the directory "dos_util" on disc 1.  This
directory also contains a number of partition manipulation utilities
including one called "fips" that can be used to resize DOS partitions
without damaging them.  Please read the file "fips.doc" in the
directory "dos_util\FIPS" on disc 1 before using it.

The "boot" and "root" images have been uncompressed, so you may ignore
the mention of "gzip" in the install notes.


Additional Information
~~~~~~~~~~~~~~~~~~~~~~
The file ls_lr is a listing of all files on all 4 CD's, in addition
each CD has a file ls_lr_# which lists all files on that CD. 

Technical Support
~~~~~~~~~~~~~~~~~

InfoMagic is pleased to provide unlimited technical support by email
to help you get Linux installed and running on your system.  Each
incoming email message will be automatically assigned a tracking
number.

Phone support is available for $2.00/minute at 900-786-5555.

We provide limited support for configuring X-Windows via email due to
the overwhelming number of combinations of video cards and monitors.

Feel free to contact us for other support options including remote
system maintenance and management contracts. 

When contacting InfoMagic Tech Support by phone, please have the
following information available: 

	Manufacturer and model of your computer
	Number, type, capacity, and "geometry" of your hard disks
	Manufacturer, model, I/O port and IRQ information on all
	  installed cards (especially sound cards and SCSI interfaces) 
	Complete text of any error messages
	Manufacturer and model of your CD-ROM drive and interface
	  details (Dedicated card, Sound card, IDE, SCSI, etc.) 

It is also helpful if you can be near your system when you call, as
we will often ask you to check configuration details or manually
adjust the system startup files.  

Please address support questions to: support@InfoMagic.com

Please do not send tech support questions to "info@infomagic.com"
or call the 800 number, they will just refer you to the above numbers
and email address!



Enjoy Linux, and check out our other CD's in the file "catalog.txt"


RoadMap
~~~~~~~
disc1/slakware			Installation disk sets
disc1/slakinst			Boot/Root disk images
disc1/Slackware_Source		Source tree for everything in Slackware
disc1/SlackELF			Slackware 2.3.0 ELF Beta
disc1/slaktest			Alternate version of CD dependant install.
disc1/docs			Assorted Linux documentation.
disc1/HOWTO			Linux Howto docs in multiple formats
disc1/help			Assorted InfoMagic supplied files
				referenced in the Quickstart Guide
disc1/dos_util			Utilities to create boot floppies
disc1/lininst			Microsoft Windows based Install Disk Builder.
disc1/usr			Live Slackware /usr filesystem for CD
				dependant installation

disc2/				Archive from sunsite.unc.edu
disc2/LDP			Writings of the Linux Documentation Project
				Includes the "guides"

disc3/tsx-11			Archive from tsx-11.mit.edu
disc3/ptolemy			ptolemy for Linux
disc3/wine			Windows Emulator archive
disc3/sunacm			Alan Cox's networking code and utilities
disc3/XFree86-3.1.1		Both a.out and ELF format
disc3/XFree86-3.1.2		Both a.out and ELF format
disc3/demos			Demos of commercial packages
disc3/viewer			HowTo docs in Microsoft Windows
				Viewer format

disc4				The RedHat Mother's Day + 0.1 distribution
disc4/JE			Japanese Extensions
disc4/JF			Japanese HowTo's
disc4/gnu			GNU archive from prep.ai.mit.edu
disc4/funet			Kernel sources (and more) from nic.funet.fi 
disc4/kernel			Assorted kernel patches from sunsite.unc.edu 

The following people have provided help and advice in the preparation
of these CD's:

Stacey Brewer (slb@infomagic.com)
Mark Horton (mah@ka4ybr.atl.ga.us)
Fred van Kempen (waltje@infomagic.com)
Henry Pierce (hmp@infomagic.com)


Slackware is a registered trademark of Patrick Volkerding, other
trademarks are the property of their respective owners.