		     Welcome to the December Edition
				of the
	     InfoMagic Linux Developer's Resource CD-ROM
			    13 October 1994

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Kernel sources up to version 1.1.72.

XFree86 3.1 integrated into Slackware.  XFree86 2.1 and XFree86 2.1.1
are also included.

DOOM for Linux.  InfoMagic provided Linux CD's to ID Software to
assist in the port and this is the reward !  You will find it in
disc2/sunsite/games/x11/action/doom.  Additional files are in
disc2/sunsite/Incoming.

A demo of FlagShip, a dBase compiler for Linux, like Clipper under
DOS.  This was made available by Mark Bolzern.

A demo of "zbbs" from Maple Leaf Software.

A demo of Executor, a MAC emulator for Linux.

A live image of a full Slackware 2.0.1 installation that may be used to
run directly from the CD via symbolic links.


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

See the RoadMap at the end of this file for the layout of the 3-CDs.

These discs are mastered in ISO-9660 format with Rock Ridge extensions
to preserve the long mixed case filenames and deeply nested directory
structure.  Every directory includes a file "YMTRANS.TBL" which lists
the ISO-9660 compliant alias and the original filename.  The sources
in the YM_UTILS directory can be used to either copy or create
symbolic links on systems that do not support the Rock Ridge
extensions.

A few large packages common to TSX-11 & SuNSITE have been merged and
put into top level directories.  This includes the kernel distributions
and XFree86.

Some popular packages have been removed due to copyright
restrictions, these include: Mosaic, Netscape, kermit, getty_ps,
ncftp, xv, and Chimera.  We applogize for the inconvenience.  These
(and more) can of course be found on our FTP server,
ftp.infomagic.com (165.113.211.2).

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

Most of the distributions can be found off the root of disc 1 in the
directory "distributions".  Included distributions and their versions
are shown below.

Slackware	2.1.0
SLS		1.0.6
TAMU		1.0-D
JE		Latest version from September
MCC		1.0+
Debian		0.91 Beta (on disc 3)
bogus		1.0.1

In the directory "lininst" on Disc 1, is a Microsoft Windows based
installation utility that will assist you in selecting the correct
boot kernel based on your hardware.  It will create the boot & root
diskettes for Slackware within Windows.  It also detects your CD
drives and floppy drives.  It may be run directly from the CD, or
copied to the hard disk.  If for some reason it does not correctly
detect your CD, you may invoke it with the drive letter on the
command line to override the automatic CD detection.

SLACKWARE 2.1.0 Notes:
~~~~~~~~~~~~~~~~~~~~~~

Slackware is found below the "distributions" directory.  The
installation sets are in the directory "slackware" to match the
InfoMagic menu option in the CD-ROM installation.  The Boot & Root
disks are in the directory "slakinst" to make them easier to find
under DOS (where long file names are not allowed :-).  Please refer
to the installation notes in the "slakware" directory before
proceeding.  Contributed software is in the directory
"distributions/slackware/contrib" on disc 1.  Refer to the
RoadMap below for the disc location of these directories.

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
to the material in the "distributions/slakinst" directory on disc 1
for help in getting started.

The tools used to create the bootable floppies, for all the
distributions, are in the directory "dos_util" on disc 1.  This
directory also contains a number of partition manipulation utilities
including one called "fips" that can be used to resize DOS partitions
without damaging them.  Please read the file "fips09.doc" before using
it.

The "boot" and "root" images have been uncompressed, so you may ignore
the mention of "gzip" in the install notes.

RAWRITE, and various other DOS utilities are provided in the
"dos_util" directory off the root of disc 1.

Note:  The directory names shown above are DOS format.  The actual
file name which will show up in Linux is "distributions/slakinst/..."


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
Tel:	602-526-9852 (Tech Support)
	602-526-9565 (Orders) 800-800-6613 (Within the US and Canada)
FAX:	602-526-9573

For support in the UK and Europe, you may contact:

Lasermoon, Ltd.
2a Beaconsfield Toad
Fareham, Hants, England. PO16 0QB
Tel:	+44 (0) 329 826444
Fax:	+44 (0) 329 825936
Email:	info@lasermoon.co.uk

In addition to Linux support, Lasermoon are experts in all manner of
Unix, Novell, and DOS systems and software.


RoadMap
~~~~~~~

disc1/distributions		Root of all included distributions
disc1/dos_util			Tools for creating boot/root disks
disc1/howto			HowTo documents in text format
disc1/viewer			Microsoft Multimedia Viewer and HowTo Docs.
disc1/lininst			MS-Windows Installation Tool
disc1/html			HowTo docs in HTML format for use
				with a WWW browser.

disc2/sunsite			Archive from sunsite.unc.edu
disc2/sunacm			Networking code from Alan Cox
disc2/live			Completely unpacked binaries from
				Slackware 2.1.0 Distribution

disc3/tsx-11			Archive from tsx-11.mit.edu
disc3/kernel			Kernel sources up to 1.1.72
disc3/X11			XFree86 2.1.0, 2.1.1, and 3.1
disc3/demos			Demos of commercial packages
disc3/debian			The debian 0.91 distribution
disc3/wine			Windows Emulator archive
disc3/other-packages		Some packages we received specific
				requests for.
disc3/JF			Japanese HowTo docs
disc3/gnu			GNU archive from prep.ai.mit.edu 


The following people have provided help and advice in the preparation
of these CD's:

Mark Horton (mah@ka4ybr.atl.ga.us)
Fred van Kempen (waltje@infomagic.com)
