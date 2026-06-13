
			    Welcome to the
	     InfoMagic Linux Developer's Resource CD-ROM
			      June 1998

Highlights of the current release:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

We have now split the Linux Developer's Resource into two products
to better server the needs and desires of our customers!  

In the past, it was difficult to know which distributions people 
want and which distributions people didn't want in a CDROM set.

We are now pleased to announce The Linux Developer's Resource
contains Linux Distributions Only (currently 4), source for the 
distributions and the distributions' updates available at press time. 
And as a NEW and SEPERATE PRODUCT, the Linux Archive CDROM, 
contains the Archives traditionally found on the Linux Developer's 
Resource.  We believe this is the kind of choice that our customers 
desire and this is the best way to provide value and choice 
to the Linux Community!

Other Information
~~~~~~~~~~~~~~~~~

Our mirrors were frozen:

	July 8th, 1998:	

		Red Hat 5.1
		Red Hat updates for 5.1
		S.u.S.E 5.2
		Slackware 3.5
		Debian 1.3.1 + bo-updates
		Debian Source
		Red Hat Contrib (binaries only)

Red Hat 5.1 for Intel including sources and updates:
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DISK 1: Red Hat 5.1
DISK 6: Red Hat Contrib and Red Hat 5.1 Updates

Red Hat has grown in popularity, diversity and ease of use
over the last two-and-half years.  We recommend it to Linux 
newcomers and people who need a stable working platform.

Through the use of Red Hat's Package Management System (RPM),
installation is straight forward and maintenance and upgrades
fairly painless (for Linux that is! ;).  You can install
Red Hat either from a single floppy or using the auto-boot.bat
file from DOS (assuming your drive is the "D" drive):

	C:\> D:
	D:\> cd dosutils
	D:\dosutils> autoboot.bat

Please note: the auto-boot.bat file should be run only in DOS mode.
Please either exit Windows 3.1 or choose the "reboot into DOS" option
under Window 95's Shut Down Menu.

NOTES:
Red Hat has adopted the GNU C Library 2.0.x (known as glibc)
as their official C library.  This means that you should not 
expect to install Red Hat rpm binary packages on older versions 
of Red Hat or other distributions using rpm as the packaging tool 
and expect them to work.  You can, of course, compile the source rpms.


S.u.S.E 5.2 and sources
~~~~~~~~~~~~~~~~~~~~~~~

DISK 2:

S.u.S.E. is a popular and well designed distribution coming from
Germany.  This is the English/German version made for InfoMagic!  S.u.S.E.
has provided software only found on their release such as enhancements
to X and the KDE desktop.  Based on RPM, its installation and and
management are as easy as Red Hat's Distribution.  This is a good
one to try out!  Please see Disc2/README or visit http://www.suse.com
for installation instructions and additional information on this
excellent distribution.

ALSO: S.u.S.E. provides copyrighted enhancements to their release of
Linux which they have made available to InfoMagic for this release.
Please do not make this release available via ftp without removing
these copyrighted features.  Please see Disc2/README for details.

Slackware 3.5 (aka Slackware 96) and sources.  
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

DISK 3

Slackware has been around for many years and use to be 
distributed on floppies before CD-ROMs became popular.  It's
install program shows its age in this respect, but nonetheless,
it is popular and not particularly difficult to install.

The boot and root images are in bootdsks.144/bootdsks.12 and rootdsks
respectively directly off the root of the Slackware CD.

The boot images are now supplied uncompressed and the root images are
used in their compressed form - If creating the root floppies
manually DO NOT UNCOMPRESS THE IMAGE FILES !

Slackware was mirrored on July 8th and reflects the last known
update, June 25th, 1998.

Debian 1.3.1
~~~~~~~~~~~~

DISK 4: Debian 1.3.1 Binaries
DISK 5: Debian 1.3.1 Sources

We apologize for not waiting for Debian 2.0 stable (aka hamm).  
At the time the decision to go to press was made, Debian 2.0 stable 
was still at least a month from being done.  We therefore thought 
it better to provide their current stable release Debian 1.3.1 
(aka "bo").  We are committed to providing the latest stable
Debian distribution available and look forward to Debian
2.0 to be on our Fall Release of the Linux Developer's Resource.

Debian remains the only "non-commercial" distribution of Linux.
Debian provides an impressive choice of software from which
a user can choose during installation.  However, this can
make it a bit more difficult for those new to the UN*X/Linux
environment.  However, the goals of Debian Project are 
certainly important and the Debian Project consistently sticks 
to the goal of providing a high quality, unencumbered Linux
Distribution.  Debian is very stable and is highly recommended
to those already very familiar with Linux who wish to try something
different.

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
	to your hard-drive as indicated above.

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

Metro-X 4.3 Enhanced Server Set (in tar and rpm format)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	In cooperation with Metrolink, we have included A 
	SINGLE USER LICENSE of the full version of the 
	Enhanced X-Server from MetroLink.  
	May be used with any Linux distribution. Please see
	DISK1/metrolink/INSTALL for general installation
	instructions. 

	WARNING: there are two versions of metroess: one for
	glibc versions of Linux and the other for libc5 versions
	of Linux.
	
		Red Hat 5.X Users Should Use:

			DISK1/metrolink/glibc/metroess-4.3.0-1glibc.i386.rpm

		SuSE 5.X Red Hat 4.X Should Use:

			DISK1/metrolink/libc5/metroess-4.3.0-1.i386.rpm
	
		Slackware 3.5 Should Use:

			DISK1/metrolink/libc5/metroess-glibc-4.3.0.tar.gz

	Slackware users and others that don't use rpm should use 
	the supplied `metroess.install` by CD'ing to:

		# cd DISK1/metrolink/<lib>
		# ./metroess.install

	Inquiries for support updates as they become available should
	be directed to support@infomagic.com.

	The Metro-X 4.3 Enhanced Server Set Normally retails for $39.
	

Kernel sources to version 2.0.34 and 2.1.108:  
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

	For a complete copy of the ftp.kernel.org archives,
	please see our new product, the Linux Archive CDROM set.
	We have provided only 2.0.34 and 2.1.108 on the LDR.

General Information about the Linux Developer's Resource
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

These discs are published every 3-4 months (or so) and
include only installable distributions of Linux.  We
have a seperate product called the Linux Archives which
contain things like sunsite, tsx-11, GNU and the kernel
archives.

NOTES:
Some popular packages have been removed due to copyright
restrictions, these include: Mosaic, kermit, xv,
and Chimera.  We apologize for the inconvenience.  These (and more)
can of course be found on our FTP server, ftp.infomagic.com
(165.113.211.32) in /pub/mirrors/linux/. 

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
	Debian

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

Phone support is available for $2.00/minute (billable to your major 
credit card) at 520-526-9573.

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

Enjoy Linux!

RoadMap
~~~~~~~
disc1				Red Hat 5.1 release for Intel with source
disc1/metrolink			MetroX 4.3 NOTE:
				glibc contains the glibc version
				libc5 contains the libc5.X version
disc1/doc/HOWTO			English version How To Documents from
disc1/doc/FAQ			English version Frequently Ask Questions

disc2				SuSE 5.2 with source	

disc3				Slackware 3.5 Release

disc4				Debian Binary CD for 1.3.1	
disc4/bo-updates		Updates to Debian 1.3.1.

disc5				Debian Source CD for 1.3.1

disc6				The stuff
disc6/netscape			Netscape 4.05 in a tar ball.
disk6/kernel			kernel 2.0.34 and 2.1.108 kernel
				source only!  Please see the Linux
				Archive CDROM companion product
				for a full archive.
disc6/RedHat/contrib		Red Hat Manhattan Contrib Archive
				(binaries only)
disc6/RedHat/updates		Red Hat supplied updates for problems
				after the initial release.  Please
				see 00README.errata for details.
				Binaries only for the updates.

[Note: We have placed the names of the distributions on the cd's themselves]

LEGAL
~~~~~
Slackware is a registered trademark of Patrick Volkerding and Walnut
Creek CD-ROM, other trademarks are the property of their respective
owners.
