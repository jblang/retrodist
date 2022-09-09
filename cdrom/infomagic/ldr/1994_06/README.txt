		     Welcome to the June Edition
				of the
	     InfoMagic Linux Developer's Resource CD-ROM

These discs are published every two months (or so) and include
snapshots of the TSX-11.MIT.EDU and Sunsite.UNC.EDU linux archives.
As with the April edition we have included the complete gnu archive from
prep.ai.mit.edu so as to be in full compliance with the GNU public
license, a copy of which is provided in the gnu directory.
We have also unpacked a number of things since the double disc set
provides us lots more room.  See the RoadMap at the end of this file.

These discs are mastered in ISO-9660 format with Rock Ridge extensions
to preserve the long mixed case filenames and deeply nested directory
structure.  Every directory includes a file "YMTRANS.TBL" which lists
the ISO-9660 compliant alias and the original filename.  The sources
in the YM_UTILS directory can be used to either copy or create
symbolic links on systems that do not support the Rock Ridge
extensions.

Beginning with this release we have included a completely unpacked
ready to run "live filesystem".  This was created by unpacking
everything in the current Slackware distribution.  It is located below
the directory "live" on Disc 2.  To use this you can either create
links to the directories on the CD or simply copy things down to your
hard disk.  Patrick (the creator of Slackware) does not recommend
running from an installation such as this, but we have provided it to
address the overwhelming demand of our users.  See notes below about
Slackware 2.0 from which this filesystem was created.

Some large packages common to tsx-11 & sunsite have been merged and
put into top level directories.  This includes the kernel distributions
and XFree86.  Other packages common to both Sunsite and TSX-11 have
been eliminated from the TSX directories.

The HowTo docs have been pulled out and put into a directory directly
off the root of disc 2.  The HowTo material is also provided in the
form of a Microsoft Multimedia Viewer title (along with the Viewer
software) for browsing/searching under Microsoft Windows.  The Viewer
supports both hypertext access to all the HowTo's and full-text
search.  You may search for single words or phrases and find all
occurances in any of the documents.  It will present a list of topics
in which your search phrase was found as well as highlighting the text
in each topic.

We have provided a setup program for the Viewer software and HowTo
docs, they may also be run directly from the CD.  From the Program
Manager of Windows, select "File/Run" and type in the following
command:

	X:\viewer\mviewer2 HowTo.MVB

where "X" is the letter corresponding to your CD-ROM.  If you prefer
you may also run the setup program found in the same directory which
will copy all the necessary files to your harddisk and create a
program manager group for the HowTo's.

All of the distributions can be found off the root of disc1 in the
directory "distributions", except Slackware.  Included distributions
and their versions are shown below.

SLS		1.0.5 with modified boot images (see below)
TAMU		1.0-A
JE		Latest version from May & June
MCC		1.0+
debian		0.91 Beta

The SLS boot images (a1.3 & a1.5) have been modified to accomodate the
directory organization of this CD and can be used to install directly
from the CD, assuming your hardware is supported.

SLACKWARE 2.0 Notes:

This release contains a significant update to Slackware.  It is
release 2.0 just announced by Patrick.  This release is in its own
directory off the root of disc1 because Patrick didn't have time to
modify the menus to accomodate another layout.  Please start by
referring to the installation notes in the directory "slakinst" off
the root of disc1.  The distribution itself is in "slakware".  The
sources that correspond to this release are on disc2 in the directory
"slacksrc".  Contributed software is in "slakcont" on disc2.

Notes for NewComers

In the howto subdirectory of the second disc there are a series of
HOWTO documents that provide detailed instructions on how to configure
and install nearly every aspect of Linux.  Please refer to these
before starting if you have never done it before !  There is some
additional material in the guide directory of disc 1.  These documents
are in UNIX(tm) format which means they do not end in CRLF, only LF
and will therefore not print on most DOS systems.  You will need to
view them with an editor or word processor (or use the included
Multimedia Viewer software)

The easiest distribution to use seems to be Slackware.  Please refer
to the material in slakinst for help in getting started.

The tools used to create the bootable floppies, for all the
distributions, are in the directory "dos_util".  This directory also
contains a number of partition manipulation utilities including one
called "fips" that can be used to resize DOS partitions without
damaging them.  Please read the file "fips09.doc" before using it.

All of the Slackware kernel images are unzipped and ready to use.  You
will need to use the RAWRITE program in \dos_util to copy it to a
floppy.  The boot images are found in the slakinst/boot12 and
slakinst/boot144 diretories.  The root disks are found in
slakinst/root12 and slakinst/root144.


Additional Information

The file "ls_ltr" contains the output of the command "ls -ltR" from the
root of the discs.  The file "00_find" contains the result of the
command "find . -type f -print" also from the root.

The utree package is provided to "browse" the filesystems on the CD's.
A prebuilt executable is in the root of each disc along with the
required startup files.  The startup file ".utree" in the root should
be copied to your home directory before running.  The qtree script
should be used to invoke utree.  A utree.usage file is provided that
contains useful information about using utree.  qtree is a shell
script that can be run from either bash or csh, but only from the
login shell.  If you are running it from another shell you must export
(or setenv) manually the UTLIB and invoke utree as shown in the qtree
script.

InfoMagic is pleased to provide as much technical support as we can.
Please do not hesitate to either email, FAX, or phone us with any
questions on installation, hardware compatibility, or any other
problem.  If we don't know the answer we will try to find it for you !

email:	support@InfoMagic.com
Tel:	609-683-8760
FAX:	609-683-5502

For support in the UK and Europe, you may contact:

Lasermoon, Ltd.
2a Beaconsfield Toad
Fareham, Hants, England. PO16 0QB
Tel:	+44 (0) 329 826444
Fax:	+44 (0) 329 825936
Email:	ian@lasermoon.co.uk

In addition to Linux support, Lasermoon are experts in all manner of
Unix, Novell, and DOS systems and software.


RoadMap
~~~~~~~

disc1/distributions		Root of all included distributions
disc1/dos_util			Utilities for creating boot floppies, etc.
disc1/guide			Install Guide in text and postscript
disc1/sunsite			Archive from sunsite.unc.edu
disc1/viewer			Microsoft Multimedia Viewer and HowTo Docs.
disc1/slakware			Slackware 2.0 distribution
disc1/slakinst			Installation notes and boot images for
				Slackware 2.0

disc2/X11			XFree86 distributions
disc2/gnu			GNU sources from prep.ai.mit.edu
disc2/tsx			Archive from tsx-11.mit.edu
disc2/live			Completely unpacked binaries from
				Slackware 2.0 Distribution
disc2/howto			HowTo documents in various formats
disc2/docs			Other documents from Sunsite docs directory
disc2/slakcont			Contributed software for Slackware 2.0
				distribution
disc2/slacksrc			Sources for the Slackware 2.0
				distribution (Compressed).

In addition each disc contains the following in the root directory:

utree and associated files, see utree.usage for info.
find_00	The result of the command "find . -type f -print" from the root
		of the discs.
ls_ltr	The result of the command "ls -ltR" also from the root.
lsm.out	A reformatted version of the Linux Software Map showing approximate
		locations of files on the two discs.  Refer to find_00
		for more accurate information.

The following people have provided help and advice in the preparation
of these CD's:

Jan Janssen (janssen@sci.kun.nl)
Fred van Kempen (waltje@aris.com)
Mark Horton (mah@ka4ybr.atl.ga.us)

