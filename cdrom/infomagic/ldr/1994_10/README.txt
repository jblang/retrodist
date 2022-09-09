		     Welcome to the October Edition
				of the
	     InfoMagic Linux Developer's Resource CD-ROM
			    3 October 1994

First we would like to thank everyone for their patience and
understanding during our move from New Jersey to Arizona.  We are
essentially back in full operation and beginning with this release
will get back to our 2-month update cycle.

This release would not have been possible without the tremendous
help of Mark Horton and Randy Jarrett.

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Kernel sources up to version 1.1.51, though we recommend only using as
high as 1.1.50, and will not provide extensive support for 1.1.51
installations.

XFree86 3.1 as just released by the XFree86 group.  XFree86 2.1 and
XFree86 2.1.1 are also included.

DOOM for Linux.  InfoMagic provided Linux CD's to ID Software to
assist in the port and this is the reward !  You will find it in
disc1/sunsite/games/x11/action/doom.

Linus's kernel archive from funet.fi

A demo of FlagShip, an DBase compiler for Linux, like Clipper under
DOS.  This was made available by Mark Bolzern.

A live image of a full Slackware 2.0.1 installation that may be used to
run directly from the CD via symbolic links.

Sources for the Slackware 2.0 distribution.


General Information about the Linux Developer's Resource
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
These discs are published every two months (or so) and include
snapshots of the TSX-11.MIT.EDU and Sunsite.UNC.EDU linux archives.
As with previous editions we have included the complete GNU archive from
prep.ai.mit.edu so as to be in full compliance with the GNU Public
License, a copy of which is provided in the "gnu directory.

See the RoadMap at the end of this file for the layout of the 2-CDs.

These discs are mastered in ISO-9660 format with Rock Ridge extensions
to preserve the long mixed case filenames and deeply nested directory
structure.  Every directory includes a file "YMTRANS.TBL" which lists
the ISO-9660 compliant alias and the original filename.  The sources
in the YM_UTILS directory can be used to either copy or create
symbolic links on systems that do not support the Rock Ridge
extensions.

Some large packages common to TSX-11 & SuNSITE have been merged and
put into top level directories.  This includes the kernel distributions
and XFree86.  Other packages common to both SuNSITE and TSX-11 have
been eliminated from the TSX directories.

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

All of the distributions can be found off the root of disc 1 in the
directory "distributions".  Included distributions and their versions
are shown below.

Slackware	2.0.1
SLS		1.0.5
TAMU		1.0-A
JE		Latest version from May & June
MCC		1.0+
Debian		0.91 Beta


SLACKWARE 2.0.1 Notes:
~~~~~~~~~~~~~~~~~~~~~~
This release is a minor update to Slackware 2.0.  The kernel versions
are unchanged from 2.0.  Later kernels can be built from the sources
and patch files provided in the "funet" directory.  Slackware is found
below the "distributions" directory.  The installation sets are in the
directory "slackware" to match the InfoMagic menu option in the CD-ROM
installation.  The Boot & Root disks are in the directory "slakinst" to
make them easier to find under DOS (where long file names are not
allowed :-).  Please refer to the installation notes in the "slakware"
directory before proceeding.  Contributed software is in the directory
"distributions/slackware/contrib" on disc 1 and sources for the 2.0 release
are in the "slacksrc" directory on disc 2.  Refer to the RoadMap below for
the disc location of these directories.

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

You will need to use the GZIP program with the -D switch to uncompress
the boot and root images, and then use the RAWRITE program to copy
them to a DOS formatted floppy.  The boot images are found in the
\distribu\slakinst\boot12 and \distribu\slakinst\boot144 diretories.
The root disks are found in \distribu\slakinst\root12 and
\distribu\slakinst\root144.

GZIP & RAWRITE are provided in the "dos_util" directory off the root of
disc 1.

Note:  The directory names shown above are DOS format.  The actual
file name which will show up in Linux is "distributions/slakinst/..."


Additional Information
~~~~~~~~~~~~~~~~~~~~~~
The file "00_find" contains the result of the command:
"find . -type f -print" from the root of both discs.

The "utree" package is provided to "browse" the filesystems on the CD's.
A prebuilt executable is in the root of each disc along with the
required startup files.  The startup file ".utree" in the root should
be copied to your home directory before running.  The "qtree" script
should be used to invoke "utree".  A file named "utree.usage" is provided which
contains useful information about using "utree".  "qtree" is a shell
script that can be run from either bash or csh, but only from the
login shell.  If you are running it from another shell you must export
(or setenv) manually the UTLIB and invoke "utree" as shown in the "qtree"
script.

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
disc1/dos_util			Utilities for creating boot floppies, etc.
disc1/guide			Install Guide in text and postscript
disc1/howto			HowTo documents in text format
disc1/sunsite			Archive from sunsite.unc.edu
disc1/viewer			Microsoft Multimedia Viewer and HowTo Docs.

disc2/x11			XFree86 distributions including XF386-3.1
disc2/gnu			GNU sources from prep.ai.mit.edu
disc2/tsx			Archive from tsx-11.mit.edu
disc2/live			Completely unpacked binaries from
				Slackware 2.0 Distribution
disc2/morehowto			HowTo documents in other formats
disc2/slacksrc			Sources for the Slackware 2.0
				distribution (Compressed).
disc2/funet			Linus's Kernel source archive including
				a tar file with sources at v1.1.50
disc2/flagship			Demo of FlagShip, a dBase compiler for Linux.
 
In addition each disc contains the following in the root directory:

utree and associated files	See "utree.usage" for info.
find_00				The result of the command
					"find . -type f -print"
				from the root of the discs.

The following people have provided help and advice in the preparation
of these CD's:

Randy Jarrett (RSJ@Radio.org)
Mark Horton (mah@ka4ybr.atl.ga.us)
Fred van Kempen (waltje@infomagic.com)
Jan Janssen (janssen@sci.kun.nl)

