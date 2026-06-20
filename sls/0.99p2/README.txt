	   SLS (SOFTLANDING LINUX SYSTEM)

		INTRODUCTION

Welcome to release .99p2 of SLS (SoftLanding Linux System).  Linux is a 
free 386 unix like operating system similar to System V, and developed
by Linus Torvalds, plus a few hundred big hearted programmers on the
Internet.   SLS is NOT just an image dump of some ones Unix system.
Instead it is a distribution whose primary purposes are:

0) provide an initial installation program (for the queasy).
1) utilities compiled to use minimal disk space.
2) provide a reasonably complete/integrated U*ix system.
3) provide a means to install and uninstall packages.
4) permit partial installations for small disk configs.
5) add a menu driven, extensible system administration.
6) take the hassle out of collecting and setting up a system.
7) give non internet users access to Linux.
8) provide a distribution that can be easily updated.

SLS contains 400-500 utilities designed to provide a relatively
complete computer operating system for the sophisticated user. It
includes programs for compression, text processing, communications,
Xwindowing system, program development (Assembler, C, C++, Fortran, 
Pascal, Lisp, and Perl),  mail, spreadsheets, and word-processing.  Also 
supported  are DOS files, a DOS emulator, SCSI, CDROMs, and TCP/IP. A
387 coprocessor is emulated by the kernel if you don't have one.  Full
source code for the kernel is also provided with SLS.

The development environment includes libraries for unix and Xwindows, a
debugger that does full screen (via emacs) with support for core dumps.
Shared libraries make the most miserly use of RAM and disk space. FAQ and
Manual pages document most of the Linux utilities.  SLS requires at least
9 Meg of disk for the minimal install.  50 Meg or more is required for the
full system (not including TeX or Interviews).  You will need at least 2
Meg of RAM, 4 meg if you want to compile programs, and 8 Meg to run
Xwindows.  Note that sometimes you can get by with less, but usually with
noticeable performance limitations.
----------------------------------------------------------------------------

		INSTALLATION

Before you can install Linux on your hard drive, you must partition your
drive, and put a file system on it.  Roughly, this entails:

 - Write protect all disks (do or die).
 - Boot Linux from disk a1, mounting the root disk (disk a2).
 - Create a Linux/Minix partition with "fdisk" on your hard drive and reboot.
 - Make a file system on the partition with "mkfs" (or "mkefs", see below).
 - Use "doinstall /dev/PART": PART is your partition (eg "doinstall /dev/hda2"
   or "doinstall /dev/hda2 /dev/hda3 /usr /dev/hdb1 /usr/spool" if you wish to
   have multiple partitions, with say /usr on a different partition.

Also "doinstall" will execute the script "doinst.sh" if it is found on PART.
The final step will ask you to put a formatted floppy in the drive so the
BOOT DISK can be prepared for you.  Have one ready ahead of time.  When the
installation is complete, and you reboot from this floppy, you will be using
Linux from your hard drive.   Later, you may wish to play with /usr/src/lilo
to boot from your harddrive.  Note that if you have less than 4 Meg of RAM,
you will need to make and activate a 4 Meg swap partition, prior to installation.
For example, using /dev/hda3 for swap: "mkswap /dev/hda3 4096; swapon /dev/hda3"
Before you begin, however, you may wish to type "menu" and browse the
Instructions sub menu.  But make sure you exit "menu" before you start the
install process.  You can also print files from there using "P", or you can
use "cat README > /dev/lp1" or "cat README > /dev/lp2".

Your first task after the base install is done, should be to make backup
copies of all of your disks  (Look in the "User Commands" menu). In fact,
you should make sure all disks are write protected before you start the
installation.  After the install, you can log on as "root".  Later, you may
install interviews with: "sysinstall -series i" Note, although you can use
the Extended FS type, it is not recommended (read as not tested), and is 
subject to change.
----------------------------------------------------------------------------

		EXAMPLE PARTITIONING PROCEDURE

... Put disk a1 in drive A: and reboot computer, then put disk a2 in the
... floppy drive you will be doing the install from (usually A: as well).

/# fdisk
 
Command (m for help): n
Command action
   e   extended
   p   primary partition (1-4)
p
Partition number (1-4): 2
First cylinder (500-977): 500
Last cylinder or +size or +sizeM or +sizeK (500-977): 977
 
Command (m for help): t
Partition number (1-4): 1
Hex code (type L to list codes): 81
 
Command (m for help): v
Command (m for help): p
 
Disk /dev/hda: 5 heads, 17 sectors, 977 cylinders
Units = cylinders of 85 * 512 bytes
 
   Device Boot  Begin   Start     End  Blocks   Id  System
/dev/hda1           1       1     499   20000    4  DOS
/dev/hda2           1       1       7   30000   81  Linux/MINIX

Command (m for help): w
reboot now before doing anything else
/#
...<after the reboot>
/# mkfs /dev/hda2 30000
/# doinstall /dev/hda2
... Follow prompts, and insert disks as requested, then login as root.
----------------------------------------------------------------------------

		ADDITIONAL SLS INFORMATION

A menu interface allows the user to see what commands would be executed if
an option was selected.  Unix newbies who use SLS don't have to always stay
newbies. SLS is a binary mostly distribution (except for the kernel), and is
broken into multiple parts, or series, each of which is denoted by a letter
followed by the disk number as follows:

	a1-aN: The minimal base system
	b1-bN: Base system extras, like man pages, emacs etc.
	c1-cN: The compiler(s), gcc/g++/p2c/f2c
	x1-xN: The X-windows distribution
	t1-tN: TeX (document processing)

This scheme allows new disks to be added to the distribution without
changing the disk numbering.  Also, the sysinstall program doesn't have to
be changed when new disks are added as the last disk is marked by the
presence of the file "install.end".  And when interviews is added, say as
a new series "i", it can be installed with:

	sysinstall -series i

Highlights of the base are:  gcc/g++, emacs, kermit, elm/mail/uucp, gdb, sc
(spreadsheet), man pages, groff, elvis, zip/zoo/lh and menu.  Highlights of
X are: X, programmers libs, 75 dpi fonts, games (spider, tetris, xvier,
chess, othello, xeyes, etc) and utilities like xmag, xmenu, xcolormap and
ghostscript.  Approximate usage is as follows:

Tiny base system:        9 Meg  (Series 'a')
Main base system:       25 Meg  (Series 'a', 'b' and 'c')
Main base system + X11: 45 Meg  (Series 'a', 'b', 'c' and 'x')
----------------------------------------------------------------------------

		LINUX SPECIFIC INFORMATION

Linux supports multiple VC's (virtual consoles).  You can switch from one 
to the other using the "LEFT-ALT-FN" keys.  The right ALT key will not work.
The console in linux more or less emulates a VT100.  So you can usually
just use kermit to do your remote logins (even while doing the install :-).
If you have a color monitor, you can even use color using the "setterm"
utility, or just execute the "/etc/startcons" script to have all VC's set
to default values.  If your screen gets garbled, you can use "reset".
Up arrow recalls previous commands.   Use the "man" command to read the
Linux manual pages, and the "man -k X" to list commands with the keyword
"X" in the command description.  The system editor is "vi" but you might
find "joe" easier to learn.

Never just power off your Linux system.  Instead type "sync", wait a sec,
then powerdown or reboot.   If your disk gets in trouble (or every
couple of weeks anyways) you may wish to run "fsck -av PART" where PART
is your partition, to try to fix any problems.

Dos files can be accessed in one of two ways.  The first uses the mtools
commands (mdir, mcopy, mtype, ...).  The file "/etc/mtools" may need
some tweeking, especially if you use mformat.  The second method is to
mount the dos disk/partition onto a directory.  eg: 

	mount -t msdos /dev/fd0 /user

Swapping can be set up of size SIZE, to a partition or to a file using:

	mkswap file SIZE
	swapon file

Linux can be booted without the floppy using /usr/src/lilo.  Important 
directories include:

"/etc"		- System configuration information
"/usr/src"	- Miscellaneous packages.
"/usr/X386/*"	- Xwindows stuff
----------------------------------------------------------------------------

		CONFIGURING X-WINDOWS

Getting X-windows to run on your PC can sometimes be a bit of a sobering 
experience, mostly because there are so many types of video cards for the PC.  
Linux X11 supports only VGA type video cards, but there are so many types of 
VGA's that only certain ones are fully supported.  SLS comes with two Xwindows 
servers.  The full color one, X386, supports some or all ET300, ET400, PVGA1,
GVGA, Trident, and ATI plus.  Others may or may not work.

The other server, X386mono, should work with virtually any VGA card, but only 
in monochrome mode.  Accordingly, it also uses less memory, and should be
faster than the color one.  But of course it doesn't look as nice.

The bulk of the Xwindows configuration information is stored in the directory
"/usr/X386/lib/X11/".  In particular, the file "Xconfig" defines the timings
for the monitor and the video card.  Setting up the monochrome server is pretty
straightforward.  

	cd /usr/X386/bin/ 
	mv -i X386 X386color		# don't overwrite old one
	mv X386mono X386
	cd /usr/X386/lib/X11/
	mv -i Xconfig Xconfig.color	# don't overwrite old one
	mv Xconfig.mono Xconfig

Now you just have to edit Xconfig to set the mouse device and type "startx".
Setting up the color server is similar, except that usually, you need to
figure out the clock timings to put in Xconfig.  README.modegen explains
how you can use the spreadsheet to figure out your clock timings based upon
your monitor specifications.  More information can be found in the directory
/usr/X386/lib/X11.  But be prepared to fiddle.
----------------------------------------------------------------------------

		AVAILABILITY

SLS is available from the address below for a $3.25/disk US ($4.00/disk 
Canadian) copying charge.  Add $1.00/disk for 3 1/2" disks, and $10.00 for
shipping and handling.  Mail payment, either cheque or money order, 
in advance, to Softlanding.   Visa and Mastercard are now also accepted,
albeit with a 4% surcharge.  Because people keep asking about prices,
Softlanding has provided this commonly ordered configurations price sheet:

NAME #DISKS  SERIES 	     5 1/4 DISKS               3 1/2 DISKS
----------------------------------------------------------------------------
TINY  4      a            US $23.00 (CDN $26.00)     US $27.00 (CDN $30.00)
BASE  17     a,b,c        US $65.25 (CDN $82.00)     US $82.25 (CDN $100.00)
MAIN  25     a,b,c,x      US $95.25 (CDN $110.00)    US $116.25 (CDN $135.00)
FULL  30     a,b,c,x,t    US $107.50 (CDN $130.00)   US $137.50 (CDN $160.00)

When ordering, ensure that you specify the bootdisk type (3 1/2 or 5 1/4).
Also, Softlanding is now offering support subscriptions for SLS.
Individual support, (one user, one machine) is $100.00 per year.
Group support, primarily for resellers and corporate sites is $1000.00 per year.

	Softlanding Software               
	910 Lodge Ave. 
	Victoria, B.C., Canada             
	V8X-3A8            
	(604) 360-0188

See Softlanding for a gentle touch down from a DOS bailout.
