
			    Welcome to the
	     InfoMagic Linux Developer's Resource CD-ROM
			      January 1998

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Our mirrors were frozen:

	January 17th, 1998:	

		RedHat 5.0
		RedHat updates for 5.0
		Slackware 3.4
		sunsite.unc.edu
		tsx-11
		gnu
		RedHat Contrib
		powertools-5.0
			 
	January 19th, 1998:

		SuSE 5.1

Red Hat 5.0 for Intel including sources and updates:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Red Hat has grown in popularity, diversity and ease of use
over the last two years.  We recommend it to Linux 
newcommers and people who need a stable working platform.

Through the use of Red Hat's Package Management System (rpm),
installation is straight forward and maintenance and upgrades
fairly painless (for Linux that is! ;).  You can install
Red Hat either from a single floppy or using the autoboot.bat
file from DOS (assuming your drive is the "D" drive):

	C:\> D:
	D:\> cd dosutils
	D:\dosutils> autoboot.bat

Please note: the autoboot.bat file should be run only in DOS mode.
Please either exit Windows 3.1 or choose the "reboot into DOS" option
under Window 95's Shut Down Menu.

NOTES:
Red Hat has adopted the GNU C Library 2.0.5 as their offical C library.
This means that you should not expect to install Red Hat rpm binary
packages on older versions of Red Hat or other distributions using
rpm as the packaging tool and expect them to work.  You can, of
course, compile the source rpms.

Slackware 3.4 and sources.  
~~~~~~~~~~~~~~~~~~~~~~~~~~

Slackware has been around for many years and use to be 
distributed on floppies before CD-ROMs became popular.  It's
install program shows its age in this respect, but nonetheless,
it is popular and not particularly difficult to install.

The boot and root images are in bootdsks.144/bootdsks.12 and rootdsks
respectively directly off the root of the Slackware CD.

The boot images are now supplied uncompressed and the root images are
used in their compressed form - If creating the root floppies
manually DO NOT UNCOMPRESS THE IMAGE FILES !


S.u.S.E 5.1 and sources
~~~~~~~~~~~~~~~~~~~~~~~

S.u.S.E. is a popular and well designed distribution coming from
Germany.  This is the English/German version made for InfoMagic!  S.u.S.E.
has provided software only found on their release such as enhancements
to X and the kde desk top.  Based on rpm, its installation and and
management are as easy as Red Hat's Distribution.  This is a good
one to try out!  Please see Disc3/README or visit http://www.suse.com
for installation instructions and additional information on this
excellent distribtion.

ALSO: S.u.S.E. provides copyrighted enhancements to their release of
Linux which they have made available to InfoMagic for this release.
Please do not make this release available via ftp without removing
these copyrighted features.  Please see Disc3/README for details.



Other Features of the LDR:
~~~~~~~~~~~~~~~~~~~~~~~~~~

	Using "locate" from Linux:
	~~~~~~~~~~~~~~~~~~~~~~~~~~
	A searchable database was implemented on this release thanks to
	Michael Dwyer (mdwyer@holly.ColoState.edu).  It uses the Linux
	`locate` program which is part of the GNU findutils package.
        On Disc 1 is a file called locatedb.ldr which contains a search
	database for the entire 6 cd collection using the "locate" program
	under Linux. 

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
	As in prior releases, we have created the file ls_lr on Disc 1
	which contains a complete listing of all files on all 6 cd's.
	In addition, each CD has a file ls_lr.# which lists all files on 
	that CD.  These files can be viewed under Linux or DOS.  However,
	DOS users will need to use an editor or word processor to
	view them in order to convert to DOS's CRLF format.

	These listings were created using a Perl script generously provided
	by Marty Leisner (leisner@dsdp.mc.xerox.com) whose contribution we
	gratefully acknowledge.  The script is provided in the "infomagic"
	directory on Disc 1.

Metro-X 4.1 Enhanced Server Set (in tar and rpm format)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	A full version of the Enhanced X-Server from MetroLink.
	May be used with any Linux distribution.   and general installation
	instructions. 

	WARNING: there are two versions of metroess-4.1.0-1.i386.rpm!
	The copy in the metrolink/libc directory is for versions
	of Red Hat prior to v5.0 and for SuSE 5.1.  The version in
	metrolink/glibc is for Red Hat 5.0 only!

	After the appropriate version of metroess-4.1.0-1.i386.rpm is
	installed, both versions need the Metrolink supplied patch file:
	
	metroessp-4.1.1.971217-1.i386.rpm

	installed.  Please metrolink/README.NOW for more information.

	Slackware users and others that use non-rpm based systems 
	should install the version in DISC1/metrolink/tar by cd'ing
	to that directory and running the script ./metroess.install.
	The patch has already been applied to the tar version.  This
	version *MUST NOT* be installed on Red Hat 5.0.

	Inquiries for support updates as they become available should
	be directed to support@infomagic.com.

	The Metro-X 4.1 Enhanced Server Set Normally retails for $99.
	

Kernel sources to version 2.0.33 and 2.1.81:  
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	
	Due to the size of the combined kernel source trees (about 560MB),
	we decided to leave the source tree for linux-2.0.tar.gz and
	linux-2.0.30.tar.gz through linux-2.0.33.tgz only.  All of the major
	releases now use 2.0.30, 2.0.32 or 2.0.33. The patches patch-2.0.1.gz
	through patch-2.0.33.gz are available if you need an intermediate
	2.0.X kernel.  Please note that kernel versions 2.0.32 and 2.0.33
	fix the recently found foof bug and fix the "teardrop" security hole.

	For the 2.1.X kernels, we have left linux-2.1.0.tar.gz and
	linux-2.1.79.tar.gz through linux-2.1.81.tar.gz.  Again, we
	have included all the intermediate patches, so you can obtain
	any kernel in this series by applying the appropriate set of
	patches.

	NOTE: we have not included the bzip'd versions of the kernel
	because the bzip compression tool cannot be freely distruted
	on CDROM.  However, the contents of the bzip'd kernel files
	are identical to the gnuzip'd versions.

General Information about the Linux Developer's Resource
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These discs are published every 3-4 months (or so) and include
snapshots of the TSX-11.MIT.EDU and Sunsite.UNC.EDU linux archives.
Do to the size of these ftp sites (about 4GIG combined), the duplicity,
etc, we do prune the archives to fit on the CDROMs.

NOTES:
Some popular packages have been removed due to copyright
restrictions, these include: Mosaic, Netscape, kermit, xv,
and Chimera.  We apologize for the inconvenience.  These (and more)
can of course be found on our FTP server, ftp.infomagic.com
(165.113.211.2) in /pub/mirrors/linux/.  The list of restricted
packages continues to grow, we have followed the guidelines in the
file "info.for.cdrom.vendors" found on disc 4 in sunsite.pt1.

In the past, we elected to simply remove everything prior to 1996.
For this release, we worked harder to ensure unique, current and
relevant packages and used  more or less the following methodology to 
prune these sites:

	1. Removed all copyright material listed in
	   info.for.cdrom.vendors found on DISK4.

	2. Removed software with questionable copyrights according
	   to the *.lsm and *.readme files included with packages.

	3. Removed all duplicated source as found in the GNU
	   Archive.  We provide the GNU archive as a separate
	   archive from ftp://prep.ai.mit.edu.

	3. Removed older packages. If a source package in any of the
	   archives was found to have say, foo-1.2.src.tar.gz and
	   foo-1.3.src.tar.gz, we removed foo-1.2.src.tar.gz in favor
	   of the current version.

	4. Removed software duplicated between TSX-11 and Sunsite.
	   (packages in tsx-11 are removed in favor of sunsite).

	5. Removed binary builds where source code was available.
	   Since many of the binary builds are from 1995 and early
	   1996, many of them probably won't work on current distributions
	   without rebuilding them anyway.  We of course remove all
	   binaries built for non-intel platforms as well.

	As always, it is difficult to make these decisions as no one method
	seems to please everyone.  However, we also believe in keeping
	the disk set economical which seems to please everyone.
	If there is a package we removed from a release that you
	would like to make sure we include in the next release,
	please ask :)  Also, if their is a package that should have
	been removed because of copyright issues, please let us
	know and we will see to it it is not on the next release.

GNU:
~~~~
As with previous editions we have included the complete current
software set from the GNU archive  from prep.ai.mit.edu so as to be in 
full compliance with the GNU Public License, a copy of which is provided 
in the "gnu" directory.

Misc:
~~~~~

As with previous recent releases we no longer include the ports for
processors other than the Intel x86.  If demand for ports for other
hardware becomes sufficient, we will make them available on a separate
CD-ROM.  Let us know!

MIRRORING:
~~~~~~~~~~
The following are mirrored directly from their home sites:

	Red Hat
	Slackware
	SuSE
	XFree86
	Kernel Sources (from nic.funet.fi)
	GNU sources
	JE, JF, JG
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
~~~~~~
InfoMagic contributes a percentage of profits from the sale of these
and our other "Free Software" CD's to the following organizations:

	Free Software Foundation
	XFree86 Group

In addition we have made contributions of equipment to a number of
Linux developers as we learn of their needs (or wants).


Notes for NewComers
~~~~~~~~~~~~~~~~~~~

On Disc 1 in the "doc/HOWTO/" directory are a series of HOWTO documents
that provide detailed instructions on how to configure and install
nearly every aspect of Linux.  Please refer to these before starting
if you have never done it before !  These documents are in UNIX(tm)
format which means they do not end in CRLF, only LF and will therefore
not print on most DOS systems.  You will need to view them with an editor
or word processor.

We have also placed a copy of the "Installation and Getting Started
Guide" on disk 1 in the infomagic/ldp directory called "INSTALL.TXT"
and as with the howto's, you will need a dos editor or word processor
to view/print the document.

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
disc1				Red Hat 5.0 release for Intel with source
disc1/metrolink			MetroX 4.1 NOTE:
				glibc contains the glibc version
				libc contains the libc5.X version
disc1/doc/HOWTO			English version How To Documents
disc1/doc/FAQ			English version Frequently Ask Questions
disc1/updates			Red Hat supplied updates for problems
				for after the initial release.  Please
				see 00README.errata for details.
				Binaries only for the updates.

disc2				Slackware 3.4 Release
disc2/lesstif.org 		The Free Motif Clone From Hungry Software.
disc2/apache.org		The Apache HTTP web server
disc2/JE			More Japanese Extentions
disc2/JG			More Japanese stuff

disc3				SuSE 5.1 with source

disc4				Sunsite Archives Part 1
disc4/doc			Sunsite Documentation archives
				with non-English HOWTO's and FAQ's.
				English versions are in doc/HOWTO and
				doc/FAQ.

disc5				Sunsite Archives Part 2
disc5/				JF Japenese Documentation

disc6				All the rest of the stuff
disc6/tsx-11			TSX-11 Archives
disc6/GNU			GNU Archives
disc6/RedHatMisc/contrib	Red Hat 5.0 Contrib Archive
disc6/RedHatMisc/powertools-5.0 Red Hat Powertools Collection for RHS 5.0

[Note: We have placed the names of the archives on our site of the
 cd's themselves]

LEGAL
~~~~~
Slackware is a registered trademark of Patrick Volkerding and Walnut
Creek CD-ROM, other trademarks are the property of their respective
owners.
