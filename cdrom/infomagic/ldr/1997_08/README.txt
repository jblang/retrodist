
			    Welcome to the
	     InfoMagic Linux Developer's Resource CD-ROM
			      August 1997

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Our mirrors were frozen on August 15th, 1997.

Red Hat 4.2 for Intel including sources and updates:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Red Hat has grown in popularity, diversity and ease of use
over the last two years.  We recommend it to newcomers
to Linux and people who need a stable working platform.
Through the use of Red Hat's Package Management System (rpm),
installation is straight forward and maintenance and upgrades
fairly painless (for Linux that is! ;).  You can install
Red Hat either from a single floppy or using the autoboot.bat
file from DOS (assuming your drive is the "D" drive):

	C:\> D:
	D:\> cd dosutils
	D:\dosutils> autoboot.bat

NOTES:
RedHat has cleaned up their contrib directory so it is only
about 200MB for this release.  However, we did remove XFree86-3.2
from RHSContrib because RedHat has provided XFree86-3.3.1 in
their own updates directory.  Some other package were removed
as well because either RHS v4.2 or the updates had a more current
version.  Naturally, copyrighted material, source code for the contrib 
tree, and a few programs where we were unclear as to the copyright
have been removed. The Red Hat contrib and update trees are found on
DISK 1.  Red Hat v4.2 source tree is on DISK 5 in RedHat.SRC.
The source for XFree-3.3.1 can be found on DISK 4 in XFree86.pt2.


Slackware 3.3 (aka Slackware 96) and sources.  
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Slackware has been around for many years and use to be 
distributed on floppies before CD-ROMs became popular.  It's
install program shows its age in this respect, but nonetheless,
it is popular and not particularly difficult to install.

The boot and root images are in bootdsks.144/bootdsks.12 and rootdsks
respectively directly off the root of the Slackware CD.

The boot images are now supplied uncompressed and the root images are
used in their compressed form - If creating the root floppies
manually DO NOT UNCOMPRESS THE IMAGE FILES !

Debian GNU/Linux 1.3.1 including sources:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Debian has made freely available an image set called the 
"Debian Official CD".  The binary is on Disk 3 and the source
tree is on DISK 4.  These images were used to  create our Debian 1.3.1 
distribution.  The only difference is that we have add other software
to these disks along the lines  of the LDR but we otherwise didn't
change the Debian layout.  Also, Debian now provides an "autoboot"
from CD similar to Red Hat's.  To start the installation from DOS and
assuming your CDROM Drive is the "D" drive, the following will start
the install:

	C:\> D:
	D:\> cd \boot
	D:\boot> boot.bat

Make sure Windows is not running when doing the above.

Searching the CDs for Software:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	Using "locate" from Linux:
	~~~~~~~~~~~~~~~~~~~~~~~~~~
	A searchable database was implemented on this release thanks to
	Michael Dwyer (mdwyer@holly.ColoState.edu).  It uses the Linux
	`locate` program.  On Disc 1 is a file called locatedb.ldr
	which contains a search database for the entire 6 cd collection
	under Linux using the "locate" program. 

	We find it convenient to place the file in /usr/local/etc
	and create the following alias under bash in /etc/profile:

	alias locatedcd="locate -d /usr/local/etc/locatedb.ldr"

	Thus, typing `locatecd <string>` will print a list of
	available files on all 6 cds matching that string.

	NOTE: it is normal for the locate program to complain about 
	the locatedb.ldr file being more than 8 days old.  Just use
	the "touch" command to update the file's date when copied
	to your harddrive as indicated above.

	Using the ls_lr files:
	~~~~~~~~~~~~~~~~~~~~~~
	As in prior releases, we have created the file ls_lr on disk 1
	which contains a complete listing of all files on all 6 cd's.
	In addition, each CD has a file ls_lr.# which lists all files on 
	that CD.  These files can be viewed under Linux or DOS.  However,
	DOS users will need to use an editor or word processor to
	view them in order to convert to DOS's CRLF format.

	These listings were created using a Perl script generously provided
	by Marty Leisner (leisner@dsdp.mc.xerox.com) whose contribution we
	gratefully acknowledge.  The script is provided in the "infomagic"
	directory on disc 1.

Metro-X 3.1.8 Enhanced Server Set (in tar and rpm format)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	A full version of the Enhanced X-Server from MetroLink.
	May be used with any Linux distribution.  This version
	now includes support for the CT 555x series of video
	chips commonly found in laptops.  Please see the README
	in the MetroLink directory on Disk 1 for details of this
	and general installation instructions.  Inquiries for
	support updates as they become available should be directed
	to support@infomagic.com.
	
	It Normally retails for $99.
	

Post.Office v2.0 for Linux:
~~~~~~~~~~~~~~~~~~~~~~~~~~

	Replacement for Sendmail using WWW admin interface
	The version provided in the "demos" directory of Disc 3 is limited
	to 10 mailboxes.  This is the same server that Netscape sells as
	their "Suite Spot Mail Server".  It handles multiple domains and
	also acts as a POP3 and finger server.  Versions with additional
	capacity are available exclusively from InfoMagic.  Pricing starts
	from $75 for a 50-mailbox.  Please contact us directly for more
	information.


Kernel sources to version 2.0.30 and 2.1.50:  
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	
	Due to the size of the combined kernel source trees (about 560MB),
	we decided to leave the source tree for linux-2.0.tar.gz and
	linux-2.0.30.tar.gz only.  All of the major release now
	use 2.0.30.  The patches patch-2.0.1.gz through
	patch-2.0.29.gz are available if you need an intermediate
	2.0.X kernel.

	For the 2.1.X kernels, we have left linux-2.1.0.tar.gz,
	linux-2.1.20.tar.gz, linux-2.1.30.tar.gz, linux-2.1.40.tar.gz
	and linux-2.1.50.tar.gz.  Again, we have included all the
	intermediate patches, so you can obtain any kernel in this series
	by applying the appropriate set of patches.

	Note: linux-2.1.10.tar.gz is not on the CD-ROM but available
	      as a patch.

UNIX Cockpit, an X11 filemanager:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	A file manager for X.

SmartWare Plus from Angoss Software (www.angoss.com):
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	A demo of SmartWare PLUS from ANGOSS Software.  SmartWare PLUS is a
	cross-platform integrated product suite that includes: a Relational
	Database, Spreadsheet w/Presentation Graphics, WordProcessor, and
	Communications.  Keys to enable the demo for personal or commercial
	use are available from InfoMagic.

FlagShip Application Generator for Linux:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 	It is similar to Clipper under DOS in concept.  These were made 
	available by Mark Bolzern of Work Group Solutions.

BRU Backup for Linux (www.bruinc.com):
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	A demo version of "bru".  A backup utility for Linux.  This includes
	their new X-Window based interface to try.

Lone-Tar Backup for Linux (www.cactus.com):
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	A demo version of "lone-tar".  A backup utility for Linux.

VirtuFlex (www.virtuflex.com):
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	Is a demo for transforming static sites into dynamic
	ones by integrating databases, email, and "shopping carts", etc
	into a dynamic whole.
	
FontScope font rasterizer demo for Linux:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	Provided by Munagala V. S. Ramanath <ram@netcom.com>.
	Please contact him for more information.

 
[Note: All Demos are on Disc 3 in the "demos" directory]

General Information about the Linux Developer's Resource
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These discs are published every 3-4 months (or so) and include
snapshots of the TSX-11.MIT.EDU and Sunsite.UNC.EDU linux archives.
Do to the size of these ftp sites (about 3GIG combined), the duplicity,
etc, we do prune the sites to fit on the Caroms.

NOTE:
Some popular packages have been removed due to copyright
restrictions, these include: Mosaic, Netscape, kermit, xv,
and Chimera.  We apologize for the inconvenience.  These (and more)
can of course be found on our FTP server, ftp.infomagic.com
(165.113.211.2) in /pub/mirrors/linux/.  The list of restricted
packages continues to grow, we have followed the guidelines in the
file "info.for.cdrom.vendors" found on disc 5 in sunsite.pt1.

In the past, we elected to simply remove everything prior to 1996.
For this release, we worked harder to ensure unique, current and
relevant packages and used  more or less the following methodology to 
prune these sites:

	1. Removed all copyright material listed in
	   info.for.cdrom.vendors found on DISK5:/sunsite.pt1/

	2. Removed software with questionable copyrights according
	   to the *.lsm and *.readme files included with packages.

	3. Removed all duplicated source as found on the GNU
	   Archive.  We provide the GNU archive as a separate
	   archive anyway.

	3. Removed older packages. If a source package in any of the
	   archives was found to have say, foo-1.2.src.tar.gz and
	   foo-1.3.src.tar.gz, we removed foo-1.2src.tar.gz in favor
	   of the current version.

	4. Removed software duplicated between TSX-11 and Sunsite.

	5. Removed source packages contained in the Debian and
	   Slackware source trees.  Because both of these distributions
	   include the original source packages used to make them,
	   we saw no reason to duplicate them in the archives.

	6. Removed binary builds where source code was available.
	   Since many of the binary builds were from 1995 and early
	   1996, many of them probably won't work on current distributions
	   without rebuilding them anyway.

	As always, it is difficult to make these decisions as no one method
	seems to please everyone.  However, we also believe in keeping
	the disk set economical which seems to please most people.
	If there is a package we removed from a release that you
	would like to make sure we include in the next release,
	please ask :) 

GNU:
~~
As with previous editions we have included the complete current
software set from the GNU archive  from prep.ai.mit.edu so as to be in 
full compliance with the GNU Public License, a copy of which is provided 
in the "gnu" directory.

Misc:
~~~~

As with previous recent releases we no longer include the ports for
processors other than the Intel x86.  If demand for ports for other
hardware becomes sufficient, we will make them available on a separate
CD-ROM.  Let us know!

MIRRORING:
~~~~~~~~~
The following are mirrored directly from their home sites:
	Red Hat
	Debian
	Slackware
	XFree86
	Kernel Sources (from nic.funet.fi)
	Flagship
	GNU sources
	JE, JF
	and (naturally) sunsite and TSX.

Other packages have been provided to us by their authors.

See the RoadMap at the end of this file for the layout of the 6 CDs.

FORMAT:
~~~~~~
These discs are mastered in ISO-9660 format with Rock Ridge extensions
to preserve the long mixed case filenames and deeply nested directory
structure.  Translation tables are provided in each directory to help
find things under MS-DOS or other systems that do not support the
Rock Ridge extensions.  A directory in the root of each CD called
"rr_moved" contains files too deeply nested to be accessible under
the ISO-9660 format.  These files will appear in their correct
locations (and the directory "rr_moved" will be empty) on systems
which support Rock Ridge.  The "TRANS.TBL" file shows the original
long mixed-case UNIX(tm) filename and the ISO-9660 alias.


The following files are included with the permission of their authors:

SCSI HowTo	(Drew Eckhardt)

If you find anything on these CD's that should not be distributed
commercially, please notify us so we can contact the authors for
permission or remove them from future releases.  We are careful to
remove everything we know about, but with over 2GB of material it is
quite possible we have overlooked something.

OTHER:
~~~~~
InfoMagic contributes a percentage of profits from the sale of these
and our other "Free Software" CD's to the following organizations:

	Free Software Foundation
	XFree86 Group

In addition we have made contributions of equipment to a number of
Linux developers as we learn of their needs (or wants).


Notes for NewComers
~~~~~~~~~~~~~~~~~~

On disk 1 in the "HOWTO" directory are a series of HOWTO documents
that provide detailed instructions on how to configure and install
nearly every aspect of Linux.  Please refer to these before starting
if you have never done it before !  These documents are in UNIX(tm)
format which means they do not end in CRLF, only LF and will therefore
not print on most DOS systems.  You will need to view them with an editor
or word processor.

We have also place a copy of the "Installation and Getting Started
Guide" on disk 1 in the infomagic/ldp directory called "INSTALL.TXT"
and as with the howto's, you will need a dos editor or word processor
to view/print the document.

Additional Information
~~~~~~~~~~~~~~~~~~~~~

Technical Support
~~~~~~~~~~~~~~~~

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
~~~~~~
disc1				Red Hat 4.2 release for Intel
disc1/metroLink			MetroX 3.1.8
disc1/RHCont			Red Hat Contributed Software
				RPMS only
disk1/doc/HOWTO			How To Documents
disk1/updates			Red Hat supplied updates for problems
				for after the initial release.  Please
				see 00README.errata for details.	
disk1/funet			Kernel sources for 2.0.X and 2.1.X
disk1/lesstif			The Free Motif Clone From Hungry Software.

disc2				Slackware 3.3 Release
disc2/GNU			GNU Archives
disc2/JF			Japanese stuff

disc3				Debian Linux 1.3.1
disc3/JE			More Japanese stuff
disc3/demos			Contributed Demos
disc3/XFree86.pt1		Binaries using glibc for XFree86-3.3.1
disc3/ptolemy			Ptolemy

disc4				Debian Source 1.3.1
disc4/XFree86.pt2		XFree86-3.3.1 sources and regular binaries.
disc4/sunsite.doc		Sunsite Document Tree
disc4/apache			Apache Web Server

disc5/RedHat.SRC		The Red Hat SRPMS tree.
disc5/sunsite.pt1		Sunsite Archive - Part 1
disc5/tsx-11			The TSX-11 Archives

disc6				Sunsite Archive - Part 2

[Note: We have placed the names of the archives on out site of the
 cd's themselves]

LEGAL
~~~~
Slackware is a registered trademark of Patrick Volkerding and Walnut
Creek CD-ROM, other trademarks are the property of their respective
owners.


