			    Welcome to the
	     InfoMagic Linux Developer's Resource CD-ROM
			      December 1996

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Red Hat 4.0 for Intel

Debian GNU/Linux 1.2

Metro-X 3.1 Enhanced Server Set (in tar and rpm format)
	Full version of the Enhanced X-Server from MetroLink
	May be used with any Linux distribution.
	Normally retails for $99
	

Post.Office - Replacement for Sendmail using WWW admin interface
	The version provided in the "demos" directory of Disc 6 is limited
	to 10 mailboxes.  This is the same server that Netscape sells as
	their "Suite Spot Mail Server".  It handles multiple domains and
	also acts as a POP3 and finger server.  Versions with additional
	capacity are available exclusively from InfoMagic.  Pricing ranges
	from $75 for a 50-mailbox version to $1,000 for an unlimited
	version.  Please contact us directly for more information.

Slackware 3.1 (aka Slackware 96)

Kernel sources up to version 2.1.14

Dilinux (Drop In Linux) - Installable from DOS

XFree86 3.2 including binaries for Alpha and M68K

UNIX Cockpit, an X11 filemanager.

Drivers for SDL's line of Frame-Relay and CSU/DSU products.

A demo of SmartWare PLUS from ANGOSS Software.  SmartWare PLUS is a
cross-platform integrated product suite that includes: Relational
Database, Spreadsheet w/Presentation Graphics, WordProcessor, and
Communications.  Keys to enable the demo for personal or commercial
use are available from InfoMagic.

A demo of FlagShip, an application generator for Linux, like Clipper
under DOS.  These were made available by Mark Bolzern of Work Group
Solutions.

A demo version of dbman, a dbase system for Linux.

A demo version of "bru".  A backup utility for Linux.

[Note: All Demos are on Disc 6 in the "demos" directory]

The StarOffice Beta (requires Motif Libraries)
	This is in the "apps/staroffice" directory of Disc 4.

The full Slackware 3.1 source tree.


General Information about the Linux Developer's Resource
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Please review the file "README.1ST" on Disc 3 for last minute info on the
Debian release.  The Debian group were having some last minute problems
and we were forced to send the other CD images off to mastering slightly
early while we waited for them to finalize things.  Therefore the readme
file on Disc3 will have the latest notes on that distribution.

These discs are published every 3-4 months (or so) and include
snapshots of the TSX-11.MIT.EDU and Sunsite.UNC.EDU linux archives.
As with previous editions we have included the complete GNU archive from
prep.ai.mit.edu so as to be in full compliance with the GNU Public
License, a copy of which is provided in the "gnu" directory.

Starting with this release we no longer include the ports for
processors other than the Intel x86.  The ports for other hardware are
available on a separate CD-ROM which will be selling for $10.00 and should
be available in late December.  This CD will include the ports to DEC
Alpha, SUN Sparc, MIPS, and 68K systems.

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
	JE, JF & JG
	and (naturally) sunsite and TSX.

Other packages have been provided to us by their authors.

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

The only parts of TSX we provide are the ALPHA, BETA, and packages/GCC
directories.  The majority of the other files are duplicated at Sunsite.
If there are any particular packages you feel are missing, please let us
know and we will include them on future releases.

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

The documentation directories from both Sunsite and TSX are included on
disc 2.

Included distributions and their versions are shown below.

Debian GNU/Linux	1.2
RedHat			4.0
Slackware		3.1

InfoMagic contributes a percentage of profits from the sale of these
and our other "Free Software" CD's to the following organizations:

	Free Software Foundation
	XFree86 Group

In addition we have made contributions of equipment to a number of
Linux developers as we learn of their needs (or wants).


SLACKWARE 3.1 Notes:
~~~~~~~~~~~~~~~~~~~~~~

Due to changes in the Slackware setup, the distribution now appears
directly off the root of Disc 2.  The installation sets are in the
directory "slakware" to match the expectations of the setup utility.

The boot and root images are in bootdsks.144/bootdsks.12 and rootdsks
respectively directly off the root of the Slackware CD.

The boot images are now supplied uncompressed and the root images are
used in their compressed form - If creating the root floppies
manually DO NOT UNCOMPRESS THE IMAGE FILES !


Notes for NewComers
~~~~~~~~~~~~~~~~~~~
In the "sunsite.doc\howto" subdirectory of disc 2, there are a series
of HOWTO documents that provide detailed instructions on how to configure
and install nearly every aspect of Linux.  Please refer to these
before starting if you have never done it before !  These documents
are in UNIX(tm) format which means they do not end in CRLF, only LF
and will therefore not print on most DOS systems.  You will need to
view them with an editor or word processor.


The RedHat distribution is now included in the CD set and may be
easier to install than Slackware.  Please refer to the file
"README" in the root directory of Disc 1 for instructions on
installing this distribution.

For help with installing Slackware, refer to the files in the
"docs" directory of Disc 2.

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
disc1				Red Hat 4.0 release for Intel
disc1/RHCont1			Part 1 of Red Hat Contributed Software
				RPMS only
disc1/RedContKernel		Contributed Kernels
	
disc2				Slackware
disc2/sunsite.doc		Docs from the Sunsite archive
disc2/tsx-11.doc		Docs from the TSX-11 archive
disc2/v2.0			v2.0 kernel sources from Linus's archive

disc3				Debian GNU/Linux 1.2

disc4				Sunsite Archive - Part 1
disc4/apps			Applications
disc4/distributions		dilinux and mini-linux
disc4/games			All manner of games for both VGA and X-Windows
disc4/X11			X11 addons and applications

disc5				Sunsite Archive - Part 2
disc5/ALPHA			ALPHA development from TSX-11
disc5/BETA			BETA drivers from TSX-11
disc5/GCC			H. J. Lu's GCC archive from TSX-11
disc5/SSALPHA			ALPHA development from Sunsite
disc5/cdrom-drivers		Archive from Germany of latest CD-ROM drivers
disc5/devel			Development tools from Sunsite
disc5/gnu			GNU archive from prep.ai.mit.edu
disc5/kernel			Kernel addons from Sunsite
disc5/libs			Assorted libraries from Sunsite
disc5/search			LSM (Linux System Map) and search utilities
disc5/system			System tools and utilities from Sunsite
disc5/utils			Assorted Utilities from Sunsite

disc6				Extras & MetroX
disc6/JE			Japanese Extensions
disc6/JF			Japanese HowTo's
disc6/JG			Another version of Japanese extensions
disc6/XFree86			From xfree86.org
disc6/jolt			Non-Sun Java tools
disc6/ptolemy			Latest version from Berkeley
disc6/v2.1			v2.1 Kernel sources from Linus's archive
disc6/wine			Wine development archive
disc6/metrox			Metro-X Servers
disc6/demos			Demos of Commercial Packages
disc6/networking		Networking archive from ftp.linux.org.uk
disc6/RHCont2			Part 2 of Red Hat contributed software
				RPMS only
disc6/RedContMisc		Misc. Red Hat contributed software

Slackware is a registered trademark of Patrick Volkerding and Walnut
Creek CD-ROM, other trademarks are the property of their respective
owners.

