			    Welcome to the
	     InfoMagic Linux Developer's Resource CD-ROM
			    November 1995

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Debian 1.0 (ELF)

RedHat 2.1 (ELF)

Slackware 3.0 (ELF)

Kernel sources up to version 1.2.13 and 1.3.42

Preliminary DEC ALPHA/AXP port (Located in "ALPHA/alpha" on Disc 5)

XFree86 3.1.2 (integrated in Debian, RedHat, and Slackware)
Includes new server for Trident TGUI 9440AGi chipset.

A fully functional demo of Pathfinder.  This is a visual source code
browser for C/C++, Tcl and iTcl.  It also includes the "Open Desktop
Graphical Frontend" for relational databases.

UNIX Cockpit, an X11 filemanager.

Drivers for SDL's line of Frame-Relay and CSU/DSU products.

A demo of SmartWare PLUS from ANGOSS Software.  SmartWare PLUS is a
cross-platform integrated product suite that includes: Relational
Database, Spreadsheet w/Presentation Graphics, WordProcessor, and
Communications.  Keys to enable the demo for personal or commercial
use are available from InfoMagic.

A demo of FlagShip, an application generator for Linux, like Clipper
under DOS.  A demo of "webkit" a tool for integrating Flagship with a
WWW server.  These were made available by Mark Bolzern of Work Group
Solutions.

A demo version of dbman, a dbase system for Linux.

A demo version of "bru".  A backup utility for Linux.

GPPLINUX, a demo of an Object Oriented development environment for Linux.

The GPM (Garden Point Modula) Modula-2 and Oberon compilers for Linux.

[Note: All Demos are on Disc 2 in the "demos" directory]

The complete "usr" filesystem from Slackware 3.0 which may be used
for a CD-ROM dependant installation.

The full Slackware 3.0 source tree.


General Information about the Linux Developer's Resource
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
These discs are published every 3-4 months (or so) and include
snapshots of the TSX-11.MIT.EDU and Sunsite.UNC.EDU linux archives.
As with previous editions we have included the complete GNU archive from
prep.ai.mit.edu so as to be in full compliance with the GNU Public
License, a copy of which is provided in the "gnu" directory.

The following are mirrored directly from their home sites:
	Slackware
	wine
	Kernel Sources (from nic.funet.fi)
	Networking Code (from ftp.linux.org.uk)
	Flagship
	GNU sources
	JE & JF
	and (naturally) sunsite and TSX.

Other packages have been provided to us by their authors.

At H. J. Lu's specific request the "private" subdirectory of the
"GCC" distribution is not included on the CD's.

See the RoadMap at the end of this file for the layout of the 5 CDs.

These discs are mastered in ISO-9660 format with Rock Ridge extensions
to preserve the long mixed case filenames and deeply nested directory
structure.  Translation tables are provided in each directory to help
find things under MS-DOS or other systems that do not support the
Rock Ridge extensions.  A directory in the root of each CD called
"rr_moved" contains files too deeply nested to be accessable under
the ISO-9660 format.  These files will appear in their correct
locations (and the directory "rr_moved" will be empty) on systems
which support Rock Ridge.  The "TRANS.TBL" file shows the original
long mixed-case UNIX(tm) filename and the ISO-9660 alias.

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

Debian		1.0
RedHat		2.1
Slackware	3.0

In the directory "lininst" on Disc 1, is a Microsoft Windows based
installation utility that will assist you in selecting the correct
boot kernel based on your hardware.  It will create the boot & root
diskettes for Slackware within Windows.  It also detects your CD
drives and floppy drives.  It may be run directly from the CD, or
copied to the hard disk.  If for some reason it does not correctly
detect your CD, you may invoke it with the drive letter on the
command line to override the automatic CD detection.

SLACKWARE 3.0 Notes:
~~~~~~~~~~~~~~~~~~~~~~

Due to changes in the Slackware setup, the distribution now appears
directly off the root of Disc 1.  The installation sets are in the
directory "slakware" to match the expectations of the setup utility.
The directory "slaktest" is used for CD dependant installs as
explained in the Slackware setup screens.

The Boot & Root disks are in the directory "slackwar" to make them
easier to find under DOS (where long file names are not allowed :-).
Please refer to the installation notes in the "slackwar" directory
before proceeding.  Contributed software is in the directory
"slackwar/contrib" on disc 1.

The complete source tree is in "slackwar/source" also on Disc 1.
This tree contains a set of scripts to build either the entire tree
of any part of it.  These scripts are called SlackBuild.

The boot images are now supplied uncompressed and the root images are
used in their compressed form - If creating the root floppies
manually DO NOT UNCOMPRESS THE IMAGE FILES !


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
"slackwar" directory of Disc 1.

The tools used to create the bootable floppies, for all the
distributions, are in the directory "utils" on disc 1.  This
directory also contains a number of partition manipulation utilities
including one called "fips" that can be used to resize DOS partitions
without damaging them.  Please read the file "fips.doc" in the
directory "utils\FIPS" on disc 1 before using it.


Additional Information
~~~~~~~~~~~~~~~~~~~~~~
The file ls_lr is a listing of all files on all 5 CD's, in addition
each CD has a file ls_lr_# which lists all files on that CD. 

These listings were created using a Perl script generously provided
by Marty Leisner (leisner@dsdp.mc.xerox.com) whose contribution we
gratefully acknowledge.  The script is provided in the "utils"
directory on disc 1.

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
disc1/slackwar			Boot/Root disk images, readme files,
				sources, and contributed software
disc1/slaktest			Alternate version of CD dependant install.
disc1/HOWTO			Linux Howto docs in multiple formats
disc1/docs			Assorted Linux documentation
disc1/docs/HTML			Linux documentation in HTML format,
				only usable by browsers under Linux
				due to long filenames.
disc1/fixes			InfoMagic supplied fixes for some
				minor problems with Slackware
disc1/help			Assorted InfoMagic supplied files
				referenced in the Quickstart Guide
disc1/utils			Utilities to create boot floppies
disc1/lininst			Microsoft Windows based Install Disk Builder.
disc1/live			Live Slackware /usr filesystem for CD
				dependant installation
disc1/wine			Windows(tm) Emulator development archive
	
disc2/				RedHat 2.1 distribution & Demos
disc2/RedHat			Distribution sets
disc2/images			Boot Images
disc2/trees			Used during installation
disc2/doc			RedHat HowTo and related docs
disc2/dosutils			Utilities to create boot/root floppies
disc2/demos			Commercial Demos
disc2/Networking		Networking archive from ftp.linux.org.uk
disc2/JE			Japanese Extensions
disc2/libs			Assorted libraries from the Sunsite archive

disc3/debian			Debian 1.0 distribution
disc3/gnu			GNU archive
disc3/kernel/funet		Linus's Kernel archive and assorted
				patches 
disc3/kernel/extras		Kernel directory from Sunsite,
				includes assorted patches and updates.
disc3/JF			Japanese Documentation


disc4				Sunsite archive

disc5/tsx-11			TSX-11 archive
disc5/XFree86			Binary distribution from XFree86 Group 
disc5/ALPHA			ALPHA packages from Sunsite
disc5/games			Games from the Sunsite archive

The following people have provided help and advice in the preparation
of these CD's:

Henry Pierce (hmp@infomagic.com)
Fred van Kempen (waltje@infomagic.com)


Slackware is a registered trademark of Patrick Volkerding, other
trademarks are the property of their respective owners.
