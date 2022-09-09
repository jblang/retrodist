			    Welcome to the
	     InfoMagic Linux Developer's Resource CD-ROM
			     August 1996

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Red Hat 3.0.3 for Intel and Alpha

Debian GNU/Linux 1.1.4

Slackware 3.1 (aka Slackware 96) with Changes as of 16 August 1996

Kernel sources up to version 2.0.12

Dilinux (Drop In Linux) - Installable from DOS (in disc5/distrib)

XFree86 3.1.2 (integrated in Debian, RedHat, and Slackware)
Includes new server for Trident TGUI 9440AGi chipset.

Raven - A Linux oriented "ezine"

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

[Note: All Demos are on Disc 2 in the "demos" directory]

The StarOffice Beta (requires Motif Libraries)

The full Slackware 3.1 source tree.


General Information about the Linux Developer's Resource
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
These discs are published every 3-4 months (or so) and include
snapshots of the TSX-11.MIT.EDU and Sunsite.UNC.EDU linux archives.
As with previous editions we have included the complete GNU archive from
prep.ai.mit.edu so as to be in full compliance with the GNU Public
License, a copy of which is provided in the "gnu" directory.

The following are mirrored directly from their home sites:
	Red Hat
	Debian
	Slackware
	wine
	XFree86
	Kernel Sources (from nic.funet.fi)
	Networking Code (from ftp.linux.org.uk)
	Flagship
	GNU sources
	JE & JF
	and (naturally) sunsite and TSX.

Other packages have been provided to us by their authors.

At H. J. Lu's specific request the "private" subdirectory of the
"GCC" distribution is not included on the CD's.

At the request of Red Hat software, we have not included the beta of
their upcoming "rembrandt" release.

Marc Ewing of Red Hat Software granted us explicit permission to include
their port for the DEC Alpha.  We have included a stripped down
version of this release, even with 6 CD's something has to go !  In
particular we have not included the entire source tree for the Alpha
version, only the kernel sources.
The complete SRPMS are included for the 3.0.3 Intel version.

See the RoadMap at the end of this file for the layout of the 6 CDs.

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

Many large packages common to TSX-11 & SuNSITE have been merged and
put into top level directories.  This includes the kernel distributions
and XFree86.

Some popular packages have been removed due to copyright
restrictions, these include: Mosaic, Netscape, kermit, getty_ps, xv,
and Chimera.  We apologize for the inconvenience.  These (and more)
can of course be found on our FTP server, ftp.infomagic.com
(165.113.211.2).  The list of restricted packages continues to grow,
we have followed the guidelines in the file "info.for.cdrom.vendors"
found on disc 4.

The following files are included with the permission of their authors:

SCSI HowTo	(Drew Eckhardt)
ncftp		(Mike Gleason)


If you find anything on these CD's that should not be distributed
commercially, please notify us so we can contact the authors for
permission or remove them from future releases.  We are careful to
remove everything we know about, but with over 2GB of material it is
quite possible we have overlooked something.

The Linux How To documents can be found below the "docs" directory on
disc 3.  They are provided in a number of formats.

Included distributions and their versions are shown below.

Debian GNU/Linux	1.1.4
RedHat			3.0.3 for Intel and Alpha
Slackware		3.1

InfoMagic contributes a percentage of profits from the sale of these
and our other "Free Software" CD's to the following organizations:

	Free Software Foundation
	XFree86 Group

In addition we have made contributions of equipment to a number of
Linux developers as we learn of their needs (or wants).


SLACKWARE 3.1 Notes:
~~~~~~~~~~~~~~~~~~~~~~

The distribution of Slackware included in this CD set incorporates
some changes and fixes released after "The Official Slackware 3.1"
CD's were mastered.  For a complete list of these fixes refer to
"changes.txt" in the "slackwar" directory on Disc 1.

The NTeX font problem described below is fixed in this updated
version.  We have confirmed that these fixes have been made.

The NTeX package included in Slackware 3.1 includes some incorrect
fonts.  The "Computer Modern Roman" fonts are in violation of the
copyright held by Donald Knuth and do not function properly besides.
Dr. Knuth's copyright requires that no font may be called "Computer
Modern Roman" except his own.  The version provided in the NTeX
package has been modified.  Please refer to the URL:

	http://www-cs-faculty.stanford.edu/~knuth/cm/html

for a complete discussion of this problem.  The flaw seems to be
deeply embedded in the NTeX distribution and therefore InfoMagic
suggests not installing the "T" series of Slackware 3.1, but rather
installing the "teTeX" distribution from the sunsite archive.  This
package may be found in the following location:

	disc4/apps/tex/teTeX/distrib

We have confirmed that this package uses the correct "Computer Modern
Roman" fonts.  For the adventurous, we have also provided the correct
"mf" files in a directory "texfix" on Disc 1.  These files are:

	roman.mf
	romlig.mf
	punct.mf

Due to changes in the Slackware setup, the distribution now appears
directly off the root of Disc 1.  The installation sets are in the
directory "slakware" to match the expectations of the setup utility.

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
In the "docs\howto" subdirectory of disc 3, there are a series of
HOWTO documents that provide detailed instructions on how to configure
and install nearly every aspect of Linux.  Please refer to these
before starting if you have never done it before !  These documents
are in UNIX(tm) format which means they do not end in CRLF, only LF
and will therefore not print on most DOS systems.  You will need to
view them with an editor or word processor.


The RedHat distribution is now included in the CD set and may be
easier to install than Slackware.  Please refer to the file
"README" in the root directory of Disc 2 for instructions on
installing this distribution.

For help with installing Slackware, refer to the files in the
"slackwar" directory of Disc 1.

Additional Information
~~~~~~~~~~~~~~~~~~~~~~
The file ls_lr is a listing of all files on all 6 CD's, in addition
each CD has a file ls_lr_# which lists all files on that CD. 

These listings were created using a Perl script generously provided
by Marty Leisner (leisner@dsdp.mc.xerox.com) whose contribution we
gratefully acknowledge.  The script is provided in the "extras"
directory on disc 1.

Technical Support
~~~~~~~~~~~~~~~~~

InfoMagic is pleased to provide unlimited technical support by email
to help you get Linux installed and running on your system.  Each
incoming email message will be automatically assigned a tracking
number.

Please address support questions to: support@InfoMagic.com

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

Please do not send tech support questions to "info@infomagic.com"
or call the 800 number, they will just refer you to the above numbers
and email address!



Enjoy Linux, and check out our other CD's in the file "catalog.txt"
provided in the "extras" directory on Disc 1.


RoadMap
~~~~~~~
disc1/slakware			Installation disk sets
disc1/slackwar			Boot/Root disk images, readme files,
				sources, and contributed software
disc1/SRPMS			Source packages for Red Hat 3.0.3 (Intel)
disc1/extras			InfoMagic catalog and lsperl script
	
disc2/				RedHat 3.0.3 distribution & XFree86

disc3				Debian GNU/Linux 1.1.4, Docs, and Demos
disc3/JE			Japanese Extensions
disc3/JF			Japanese HowTo's
disc3/docs			"Standard" Linux Documentation
disc3/debdoc			Debian GNU/Linux 1.1.4 Documentation
disc3/wine			Windows Emulator

disc4				Sunsite Archive - Part 1
disc4/apps			Applications
disc4/devel			Development Tools and Languages
disc4/ptolemy			Latest Linux version
disc4/utils			Utilities

disc5				Sunsite Archive - Part 2
disc5/ALPHA			ALPHA development - Device drivers
disc5/X11			X11 related programs, utilities, etc
disc5/distrib			Small Linux distributions
disc5/games
disc5/libs
disc5/search			LSM and utilites to search it
disc5/system			System level "stuff" including network
				servers and utilities

disc6				Red Hat 3.0.3 for DEC Alpha, GNU, and TSX-11
disc6/gnu			GNU archives
disc6/tsx-11			ALPHA & BETA drivers from TSX
disc6/kernel			Kernel sources to 2.0.12

Slackware is a registered trademark of Patrick Volkerding and Walnut
Creek CD-ROM, other trademarks are the property of their respective
owners.

