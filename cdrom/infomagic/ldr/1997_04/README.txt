			    Welcome to the
	     InfoMagic Linux Developer's Resource CD-ROM
			      April 1997

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Red Hat 4.1 for Intel including sources and updates.

Debian GNU/Linux 1.2.10 including sources and updates.

Slackware 3.2 and sources.  

A searchable database implemented on this relase thanks to
	Michael Dwyer (mdwyer@holly.ColoState.edu).  It use the Linux
	`locate` program.  On Disc 1 are the files locatedb which contains a
	search engine for the entire 6 cd collection and each disc has a file
	called locatedb.# for just files on that cd.  To use this feature from
	Linux (or UN*X that supports locate), for example, mount disc 1,
	`cd` to the top level of the directory and type:

	locate <string> -d ./locatedb

	This will search the master data base for the program you search for.
	You can do a similar thing on each of the cd's using the locatedb.#
	for that cd.	

Metro-X 3.1.5 Enhanced Server Set (in tar and rpm format)
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


Kernel sources up to version 2.1.35

XFree86 3.2 is used by Red Hat, Debian and Slackware on this release
(both core and contrib).  Each distribution includes the source code
so the we have elected not to provide a mirror of XFree86-3.2.  We
also elected not to provied the XFree86-beta release.  As with all
X Consortium beta releases of XFree86, source code is not released and
the binaries have a built in expiritory date.  As of this release
the current XFree86-beta is due to expire June 15th 1997.  If you need
one of the servers from that release, it can be found on 
ftp.infomagic.com:/pub/mirrors/XFree86-beta/.

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

A demo version of "bru".  A backup utility for Linux.

A demo version of "lone-tar".  A backup utility for Linux.

The StarOffice Beta (requires Motif Libraries to install)
	This is in the demos directory of Disc 6.

[Note: All Demos are on Disc 6 in the "demos" directory]

General Information about the Linux Developer's Resource
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These discs are published every 3-4 months (or so) and include
snapshots of the TSX-11.MIT.EDU and Sunsite.UNC.EDU linux archives.
Things that were removed from TSX-11.MIT.EDU and Sunsite.UNC.EDU
include copyrighted material as found on Disk 5 in info.for.cdrom.vendors,
files duplicated between the archieves, and GNU software that is part
of the GNU archieves.

As with previous editions we have included the complete GNU archive from
prep.ai.mit.edu so as to be in full compliance with the GNU Public
License, a copy of which is provided in the "gnu" directory.

Starting with this release we no longer include the ports for
processors other than the Intel x86.  If demand for ports for other
hardware becomes sufficient, we will make them available on a separate
CD-ROM.  Lets us know!

The following are mirrored directly from their home sites:
	Red Hat
	Debian
	Slackware
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
(165.113.211.2) in /pub/mirrors/linux/.  The list of restricted
packages continues to grow, we have followed the guidelines in the
file "info.for.cdrom.vendors" found on disc 5.

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

Debian GNU/Linux	1.2.10
RedHat			4.1
Slackware		3.2

InfoMagic contributes a percentage of profits from the sale of these
and our other "Free Software" CD's to the following organizations:

	Free Software Foundation
	XFree86 Group

In addition we have made contributions of equipment to a number of
Linux developers as we learn of their needs (or wants).


SLACKWARE 3.2 Notes:
~~~~~~~~~~~~~~~~~~~~~~

Due to changes in the Slackware setup, the distribution now appears
directly off the root of Disc 2.  The installation sets are in the
directory "slakware" to match the expectations of the setup utility.

The boot and root images are in bootdsks.144/bootdsks.12 and rootdsks
respectively directly off the root of the Slackware CD.

The boot images are now supplied uncompressed and the root images are
used in their compressed form - If creating the root floppies
manually DO NOT UNCOMPRESS THE IMAGE FILES !

Red Hat v4.1 Notes
~~~~~~~~~~~~~~~~~~

We have tried to provided as much of the Red Hat Contrib directory
as possible.  However, at 1GIG including source, we were forced
to removed some things.  Notably, copyrighted material, source
code, and a few programs were were unclear as to the copyright.
Overall, the Contrib Diretory has been broken in to 3 parts:
RHSCont1 on DISK 1, RHSCont2 (files lettered from a-p) on DISK 4,
and RHSCont2 (files lettered from q-z) on DISK 5.

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
disc1				Red Hat 4.1 release for Intel
disc1/MetroLink			MetroX
disc1/RHCont1			Part 1 of Red Hat Contributed Software
				RPMS only
disc1/RHSCont1/kernels		Contributed Kernels
disk1/LDP			Linux Documentation Project from Sunsite
disk1/updates			Red Hat supplied updates for problems
				for after the initial release.  Please
				see 00README.errata for details.	

disc2				Slackware 3.2 Release
disc2/v2.1			v2.0 kernel sources from Linus's archive

disc3				Debian GNU/Linux 1.2.10
disc3/sunsite.doc		Docs from the Sunsite archive

disc4/ALPHA			ALPHA development from TSX-11
disc4/BETA			BETA drivers from TSX-11
disc4/GCC			H. J. Lu's GCC archive from TSX-11
disc4/binaries			binaries unique to tsx-11
disc4/packages			packages unique to tsx-11
disc4/patches			patches unique to tsx-11
disc4/sources			sources unique to tsx-11
disc4/gnu			The GNU archive
disc4/ptolemy			Berkley's Ptolemy
disc4/RHSCont2/RPMS		RPMS lettered from A-Z and a-p

disc5				Sunsite Archive - Part 1
disc5/apps			Applications
disc5/distributions		mini-linux, monkey and nfsboot
disc5/games			All manner of games for both VGA and X-Windows
disc5/libs			Libraries from Sunsite
disc5/science			Science Applications
disc5/utils			Utilities
disc5/X11			X11 addons and applications
disc5/RHSCont3			RPMS lettered from q-z

disc6				Sunsite Archive - Part 2
disc6/JE			Japanese Extensions
disc6/JF			Japanese HowTo's
disc6/JG			Another version of Japanese extensions
disc6/v2.0			v2.1 Kernel sources from Linus's archive
disc6/demos			Demos of Commercial Packages
				RPMS only

Slackware is a registered trademark of Patrick Volkerding and Walnut
Creek CD-ROM, other trademarks are the property of their respective
owners.
