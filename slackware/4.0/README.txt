
README for Slackware Linux 4.0.0.

Slackware 4.0 is a complete distribution of the Linux operating system.  This
version contains the 2.2.6 Linux kernel, plus recent versions of these (and
other) software packages:

- Kernel modules         2.2.6
- PPP daemon             2.2.0f and 2.3.7
- Dynamic linker (ld.so) 1.9.9
- C compiler             egcs-1.1.2 and gcc-2.7.2.3
- Binutils               2.9.1.0.19a
- Linux C Library        libc.so.5.4.46
- Linux C++ Library      libstdc++.so.2.9.0
- Termcap                libtermcap.so.2.0.8
- Procps                 2.0.2
- Gpm                    1.14
- SysVinit               2.76-3
- Shadow Password Suite  shadow-19990307
- Util-linux             util-linux-2.9i
- X Window System        XFree86 3.3.3.1

Mail here _pours_ in at high volume, but feel free to report any problems you
find. I can't promise a response but I *do* appreciate the help people offer
me in fixing problems.  Also, if you do write to me, please use include a
valid email address somewhere in the message itself.  You'd be surprised how
many people I can't write back to because the return address is mangled for 
some reason.  Some of these people are even writing to me in reference to 
mail-related problems... "Why is my return address on outgoing mail wrong?" :^)


This is what you'll find in the subdirectories below:


bootdsks.144, bootdsks.12, rootdsks:
                Boot/install disks for 1.44M and 1.2M floppy drives.  You will 
                need at least one boot disk and one rootdisk to install this
                software.  See the README files in these directories for more 
                information.

slakware/a1 - slakware/a13:  The base system.  Enough to get up and running and
                have elvis and comm programs available.  Based around the 
                2.2.6 Linux kernel, and concepts from the Linux filesystem
                standard.  Installing the entire A series requires 40 MB.
                
                These disks are known to fit on 1.2M disks, although the rest 
                of Slackware won't.  If you have only a 1.2M floppy, you can 
                still install the base system, download other disks you want 
                and install them from your hard drive. 

slakware/ap1:   Linux applications.  These are some useful programs, including
                better editors, file quota utilities, a spell checker, man
                pages (and the groff package needed to process them), a Norton
                Commander clone called the Midnight Commander, extra shells, and
                other utilities.  Installing the entire AP series uses 25 MB.

slakware/d1:    Program development.  egcs-1.1.2 (gcc-2.8 based C/C++/f77/
                Objective-C compiler from egcs.cygnus.com), gcc-2.7.2.3 (C and
                C++ compiler), make (GNU and BSD), byacc and GNU bison, flex,
                5.4.46 C libraries, gdb, SVGAlib, ncurses, gcl (LISP), p2c, m4,
                perl, python-1.5.1, rcs.  Installing the entire D series will
                require 65 MB.

slakware/e1:    GNU Emacs 20.3.  This is a text editor with about a million
                extra features that allow you to read your mail, news, edit
                and compile programs, and just about anything else you might
                need to do.  Installing the entire E series will require 40 MB.

slakware/f1:    A collection of FAQs and other documentation.  Installing the
                F series requires about 13 MB.

slakware/k1:    Source code for the 2.2.6 Linux kernel.  You'll need this
                (along with the C compiler and utilities from the D series) if
                you want to recompile your Linux kernel.  Installing the K
                series will require 60 MB, and you'll need more to compile it.

slakware/n1 - slakware/n9:  Networking.  This package contains TCP/IP and UUCP
                support for Slackware, including packages to support SLIP/PPP,
                mail programs such as sendmail, pine, and elm, news readers
                like tin, trn, and nn, the Apache Web server, INN and cnews news
                servers, lynx Web browser, the netatalk Mac server, and Samba
                server for Windows networks.  Installing the entire N series
                will use 35 MB.

slakware/t1:    teTeX 0.9-990309 - teTeX is Thomas Esser's TeX distribution
                for Linux.  Installing the entire T series requires 95 MB.

slakware/tcl1:  Tcl, Tk, TclX, Tix, expect;  built with ELF shared libraries
                and dynamic loading support.  The TCL series needs about 14 MB.

slakware/y1:    Games.  The BSD games collection, Koules, Lizards, 
                and Sasteroids.  Installing the entire Y series will use about
                8 MB.

contrib         This directory contains extra packages for Slackware, such as
                the Andrew User Interface System (lets you create, use, and 
                mail multi-media documents and applications).
                
               
--------- Packages for the X window system:


slakware/x1:    The X Window System, from XFree86 3.3.3.1, with libXpm,
                fvwm2_2.0.46-BETA, and xlock added.  Also includes xf86config,
                an XF86Config writing program - just tell it your video card,
                mouse, and monitor, and it will configure XFree86 for you!
                The entire X series requires 78 MB.

slakware/xap1:  Applications for the X Window System.  Extra programs for X,
                such as file managers (TkDesk, xfm, xfilemanager), the K Desktop
                Environment (a full-featured, user friendly graphical user
                interface), a window manager that makes X resemble Windows95
                (fvwm95), graphical web browsers (Arena and Netscape
                Communicator), image editing and processing apps (xv, GNU gimp),
                a fractal generator (xfractint), communications programs, and
                more.  Installing the entire XAP series will require about
                140 MB.

slakware/xd1:   Tools to recompile X servers.  This is a kit used to relink your
                server, perhaps to compile in support for a new video card.  Not
                many people will need to install this -- this series is not
                needed to compile X applications.  Installing the XD series
                will use about 15 MB.

slakware/xv1:   xview3.2p1-X11R6.  The XView series adds support for the Open
                Look window manager (commonly used on Sun systems), and for
                compiling XView applications.  The XV series uses 11 MB.


--------- ZipSlack, an easy to download and install version of Slackware for
          DOS/Windows machines:


zipslack        This directory contains ZipSlack, a version of Slackware
                supplied as a single 35 megabyte ZIP archive.  Installation
                is as simple as unzipping zipslack.zip on a DOS partition or
                Zip disk.  It does not come with X, but is otherwise fairly
                complete, including networking and development tools.  The
                package management tools let you add as much extra software
                as you need (such as X) once you boot the system.  For more
                information, see the zipslack/README.1st file.


================================================================================


Installation notes for Slackware Linux:

A more detailed description of the installation process may be found in the
file INSTALL.TXT, the "Installation-HOWTO", by Matt Welsh.


INSTALLATION DISKS:

You will need two installation disks: a "bootdisk" and a "rootdisk".  To make
your bootdisk/rootdisk combination, you'll have to write the floppy images
onto a pair of formatted floppy disks.  (if your CD-ROM drive is bootable, you
might try booting the CD-ROM -- some Slackware CD-ROMs are directly bootable,
eliminating the need to make boot and root disks)

  _The Bootdisk_

The bootdisk contains the Linux kernel which will be used on your system, so
it's important to choose this carefully.  The bootdisk images are found
in ./bootdsks.144 (or ./bootdsks.12 if your boot floppy drive is the old 1.2
meg type) and the rootdisk images are found in ./rootdsks.  The README.TXT in
the bootdisk image directory explains the various choices in detail, but in
most cases, primarily IDE systems can use the 'bare.i' bootdisk, and systems
with a SCSI controller can use the 'scsi.s' bootdisk.

The usual way to write out the floppy is with the RAWRITE.EXE utility.  This
should be run under real MS-DOS, if possible.  People using Win95 and NT have
reported running into problems with RAWRITE.EXE, but might be able to use the
alternate version RAWRITE12.EXE.  The image is written to a floppy in drive A:
like this:

  RAWRITE.EXE bare.i a:

If you are using a Unix workstation (such as a Sun), you may write out the
image with 'cat' or 'dd' like this:

      cat bare.i > /dev/rdf0

or:   dd if=scsinet of=/dev/(rdf0, rdf0c, fd0, or whatever) obs=18k
      This uses an 18K block size, which is needed on some workstations.
      On the ones where it's not needed, it still probably doesn't hurt.

  _The Rootdisk_

You'll also need a rootdisk.  This disk is a compressed Linux filesystem
containing a basic set of Linux software, including the installation program.
The usual choice is "color.gz", which is used to install Linux onto a
dedicated Linux partition.  The image is written to a floppy in drive A:
like this:

  RAWRITE.EXE color.gz a:

You may also write the image using 'cat' or 'dd' as described above.

There are other rootdisks available for different types of installations,
such as installing into a C:\LINUX directory on an existing FAT/FAT32 drive,
or through PCMCIA devices like CD-ROM drives and ethernet cards.


PREPARING DISK SETS (floppy install only)

Slackware's A (base) and N (network) software sets can be installed from
floppy disks as well.  It's pretty rare these days for anyone to attempt an
installation from floppy disk, and it's usually only done on laptops or other
machines that have no CD-ROM drive or modem (i.e. there is no other choice).

You can skip this section if you're installing from CD-ROM or have copied the
/slakware/ directory tree (containing the .tgz packages) to your hard drive to
install from there.

To install from floppies, you'll need to make the disk sets you wish to install
on 1.44 megabyte MS-DOS formatted disks.  You'll want to download the contents
of each of the A and N subdirectories of ./slakware/, copying the files onto
the DOS floppies.  For example, to make the "A1" disk (the first floppy in the
base series), you'd copy the files in the ./slakware/a1 directory to a
floppy disk:

cd slakware
cd a1
copy *.* a:

If you need to download the files, be sure to include the index files.  These
have names like 'diska1', 'diska2', and so on.  Sometimes badly written DOS
software doesn't transfer or copy these files since they don't have a file
extension (.txt, .exe, .com, etc).  If the index files are missing, you'll
get an error that the A series can not be found.

Once you've installed the A and N series, and the machine is running Linux,
the rest of the packages you need can be installed from your hard drive.


INSTALLING FROM HARD DRIVE OR NETWORK:

If you want to install from your hard drive, just set up a directory on your
DOS, Linux, or OS/2 partition containing the the disk subdirectories for the
disk sets you want.  For example, if you wanted to install the A series, you
might make a SLACK directory on your DOS drive and copy the A1, A2, A3, A4...
directories and their contents into it.  You can then specify this as the
source to install from when you run the setup program.  Like with the CD-ROM 
installation, you'll only have to make the boot and root floppies.

To install from NFS, set up a similar directory on the NFS server you plan to
use, and then make sure the directory is exported.  If you're installing to
a laptop using PCMCIA ethernet, make sure to use the PCMCIA rootdisk.  It
contains special kernel modules to recognize PCMCIA devices.


WHAT IF MY CD-ROM IS NOT RECOGNIZED?

Don't panic -- you'll still be able to install Linux from your hard drive.
Sometimes new CD-ROM hardware comes out and doesn't work with Linux.  It can
take a while for Linux to support it because the Linux developers sometimes
aren't told about the hardware's introduction and don't hear about it at all
until people start sending email wondering why it doesn't work.  The people
making hardware almost always write a DOS driver before releasing it, so the
workaround is to copy the disk sets you want to your DOS partition (under DOS)
and then install them from there.  Here's how you'd copy the disk sets to a
C:\SLACK directory under DOS from a CD-ROM drive on e:

C:\> MKDIR SLACK
C:\> CD SLACK
C:\SLACK> XCOPY E:\SLAKWARE\*.* . /S

This will take about 150 megabytes, so if you don't have that much space you'll
have to be selective about which disk sets to copy over.  You need at least the
A series to start with.  If you want to try to get your CD-ROM running once the
system is installed you can keep an eye on sunsite.unc.edu:/pub/Linux/kernel
for new kernels or kernel patches that support your CD-ROM drive.


BOOTING THE BOOT/ROOT IMAGES

Insert the bootdisk in your floppy drive and reboot your system.  Hit ENTER when
you see the 'boot:' prompt to load and boot the Linux kernel.  The kernel will
produce lots of diagnostic information as it boots, allowing you to see if your
hardware has been detected and is working properly.  (in fact, once the boot 
process stops at the "VFS: Insert root floppy disk" message, you can use the
right shift key with the PageUp and PageDown keys to scroll back and examine
the boot messages more carefully)

When the hardware detection is complete you'll see this prompt:

  VFS: Insert root floppy disk to be loaded into ramdisk and press ENTER

Take the bootdisk out of your floppy drive, insert the rootdisk, and press
the ENTER key to load it.  The rootdisk will be uncompressed, loaded into a
ramdisk, and mounted as your root filesystem.  At this point, you may log in
as 'root'.


DRIVE PARTITIONING

Unless you're using the umsdos.gz rootdisk to install to an existing DOS 
partition, or you're already got Linux partitions on your machine, you'll need
to make one or more partitions for Linux.  Before doing any repartitioning,
you are strongly advised to back up your data!

On Linux, whole IDE drives have names like /dev/hda, /dev/hdb, /dev/hdc.  SCSI
drives have names like /dev/sda, /dev/sdb, /dev/sdc.  Within this system, disk
partitions are denoted with additional digit(s).  For example, the partitions
on /dev/hda might be /dev/hda1, /dev/hda2, and /dev/hda3.  (NOTE: Linux may
not see partitions in the same order as DOS fdisk, so it's best to use size and
type rather than number to identify partitions made from DOS or other operating
systems)

To create new disk partitions, use the Linux tool 'cfdisk'.  For example, to 
make partitions on your first IDE drive, you'd use this command to start the
cfdisk program:

 cfdisk /dev/hda

If you don't have any freespace on your system, you'll be unable to make any
partitions until you create some freespace.  One way to do this is to 
physically add another drive to the system.  Another way is to use 'cfdisk' to
delete an existing drive partition, opening up some space for a Linux partition
to be created.  The FIPS utility in Slackware's ./install directory provides a
way to shrink an existing DOS partition non-destructively (but may not work
with FAT32), and the commercial program PartitionMagic can also accomplish this
task.

Once you have freespace available, use cfdisk's "New" choice to make a Linux
partition.  You'll probably want at least 400 megabytes for a full installation.

Depending on the amount of memory in your machine, you may also want to
allocate a 64 megabyte or so partition to be used as swap space.  This will be
added to the amount of RAM in your machine to get your total virtual memory.
To make a swap partition, first use cfdisk's "New" choice to make a partition,
then use the "Type" option to change the partition's type to 82 (Linux swap).

To save the changes made in cfdisk, exit using the "Write" option.  If you
don't want to save the changes for some reason, you can exit with the "Quit"
option (or just hit Control-C).


RUNNING SETUP

Once you have a Linux partition defined, you can run 'setup' to begin the
installing Linux.  This will scan your system's disk partitions, and then
bring up the installation menu.  You can start the installation by selecting
KEYMAP (if you're using a non-US keyboard) or ADDSWAP.  More information on
running 'setup' is available from the HELP option.

Make sure you have a blank, formatted floppy ready to make your Linux boot 
disk at the end of the installation. 

[NOTE]: You may install most software packages by typing "setup" on a
running system.  If you install a kernel (such as ide.tgz or scsi.tgz) from
the A series, be sure to run LILO or make a new boot disk using the
"makebootdisk" utility.  Also, if you reinstall some of the base packages you
might need to reconfigure files in /etc or other places.  (once your system is
configured to your liking, it's wise to make a backup of the /etc directory)

You may review the list of installed packages on the installed system by
browsing through the files in /var/log/packages.  These packages may be
removed, reinstalled, or upgraded with the Slackware package maintenance
tools 'installpkg', 'removepkg', and 'pkgtool'.

Enjoy!

Patrick Volkerding
volkerdi@slackware.com

