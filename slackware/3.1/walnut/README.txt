This is Slackware Linux 3.1.0 (Slackware96)

This version contains the 2.0.0 Linux kernel, plus recent versions of these
(and other) software packages:

- Kernel modules         2.0.0
- PPP daemon             2.2.0f
- Dynamic linker (ld.so) 1.7.14
- GNU CC                 2.7.2
- Binutils               2.6.0.14
- Linux C Library        5.3.12
- Linux C++ Library      2.7.1.4
- Termcap                2.0.8
- Procps                 0.99a (with 2.0.0 patches)
- Gpm                    1.09
- SysVinit               2.62
- Util-linux             2.5

Mail here _pours_ in at high volume, but feel free to report any problems you
find. I can't promise a response but I *do* appreciate the help people offer
me in fixing problems.

This is what you'll find in the subdirectories below (or in the case of the 
disk sets, in the ./slakware subdirectory):

./bootdsks.144, ./bootdsks.12, ./rootdsks:
                Boot/install disks for 1.44M and 1.2M floppy drives. You will 
                need at least one boot disk and one rootdisk to install this
                software. See the README files in these directories for more 
                information.

./a1 - ./a8     The base system. Enough to get up and running and have elvis
                and comm programs available. Based around the 2.0.0 Linux
                kernel, and concepts from the Linux filesystem standard. 
                
                These disks are known to fit on 1.2M disks, although the rest 
                of Slackware won't. If you have only a 1.2M floppy, you can 
                still install the base system, download other disks you want 
                and install them from your hard drive. 

./ap1 - ./ap5   Various applications and add ons, such as the manual pages,
                groff, ispell, joe, jed, jove, ghostscript, sc, bc, and the
                quota patches.

./d1 - ./d13    Program development. GCC/G++/ObjectiveC/Fortran-77 2.7.2, make
                (GNU and BSD), byacc and GNU bison, flex, 5.3.12 C libraries, 
                gdb, SVGAlib, ncurses, gcl (LISP), p2c, m4, perl, rcs.

./e1 - ./e8     GNU Emacs 19.31.

./f1 - ./f2     A collection of FAQs and other documentation.

./k1 - ./k6     Source code for the 2.0.0 Linux kernel.

./n1 - ./n6     Networking. TCP/IP, UUCP, mailx, dip, PPP, deliver, elm, pine, 
                BSD sendmail, Apache httpd, arena, lynx, cnews, nn, tin, trn,
                inn.

./t1 - ./t9     NTeX Release 1.2.1 - NTeX is a very complete TeX distribution
                for Linux.  Thanks to Frank Langbein for contributing this!

./tcl1 - ./tcl2 Tcl, Tk, TclX, built with ELF shared libraries and dynamic
                loading support.  Also includes the TkDesk filemanager.

./y1            Games. The BSD games collection, Tetris for terminals, 
                Lizards, and Sasteroids.

./contrib       This directory contains extra packages for Slackware, such as
                an Ada compiler, and the Andrew User Interface System (lets
                you create, use, and mail multi-media documents and 
                applications).
                
               
--------- Disks for the X window system:

./x1 - ./x16    The base XFree86 3.1.2 system, with libXpm, fvwm 1.23b, and 
                xlock added. Also includes xf86config, an XF86Config writing
                program - just tell it your video card, mouse, and monitor,
                and it will create your XF86Config file for you!

./xap1 - ./xap4 X applications: X11 ghostscript, libgr, seyon, workman, 
                xfilemanager, xv 3.10, GNU chess and xboard, xfm 1.3.2,
                ghostview, gnuplot, xpaint, xfractint, fvwm95-2, and various
                X games. 

./xd1 - ./xd3   X11 server linkkit, static libraries, and PEX support.

./xv1 - ./xv3   xview3.2p1-X11R6. XView libraries, and the Open Look 
                virtual and non-virtual window managers for XFree86.

================================================================================

Installation notes for Slackware96 Linux 3.1.0:

A more detailed description of the installation process may be found in the
file INSTALL.TXT, the "Installation-HOWTO", by Matt Welsh.


INSTALLATION DISKS:

You will need installation disks: a "bootkernel" disk and a "root/install" disk.

To make your bootkernel/rootdisk combination, you'll have to get a boot kernel
and root disk.  Bootkernels are in ./bootdsks.12 (for 1.2 meg drives) and 
./bootdsks.144 (for 1.44 meg drives).  Rootdisks are in ./rootdsks.  Use 'dd' 
or RAWRITE.EXE to write them to floppies.

  NOTE: When using dd to create the boot kernel disk or root disk on Suns and 
  possibly some other Unix workstations you must provide an appropriate block
  size.  This probably wouldn't hurt on other systems, either.  Here's an 
  example: 

  dd if=scsinet of=/dev/(rdf0, rdf0c, fd0, or whatever) obs=18k


DISK SETS

If you're installing from CD-ROM, you don't need to make any disk sets.  Just
select the ones you want during the installation process.  However, if you're 
installing from floppy disk, you'll need to make the disk sets you wish to 
install on MS-DOS formatted disks.  The A disks will fit on 1.2 MB or 1.44 MB 
disks, but all other disk sets require 1.44 MB disks.  So, if you're installing
from floppy using a 1.2 MB drive, you'll only be able to install the A series 
at first.  Once your machine is running Linux the rest of the packages you need
can be installed from your hard drive.

These are the disk sets that are available to install:

      A   - Base Linux system (required)
      AP  - Various applications that do not need X
      D   - Program Development (C, C++, Kernel source, Lisp, Perl, etc.)
      E   - GNU Emacs 
      F   - FAQ lists 
      K   - Linux kernel source
      N   - Networking (TCP/IP, UUCP, Mail)
      T   - TeX
      TCL - Tcl script language, and Tk toolkit for developing X apps
      X   - XFree86 X Window System
      XAP - Applications for X
      XD  - XFree86 X server development system, PEX extensions, and man
	    pages for X programming.
      XV  - XView. (OpenLook[TM] [virtual] Window Manager, apps)
      Y   - Games (that do not require X)

For each disk, make an MS-DOS format disk and copy the proper files to it.
The "00index.txt" files are added by the FTP server. You don't need those.

Make sure you have a blank, formatted floppy ready to make your Linux boot 
disk at the end of the installation. 

INSTALLING FROM HARD DRIVE OR NETWORK:

If you want to install from your hard drive, just set up a directory on your
DOS, Linux, or OS/2 partition containing the the disk subdirectories for the
disk sets you want.  For example, if you wanted to install the A series, you
might make a SLACK directory on your DOS drive and copy the A1, A2, A3, A4,
and A5 directories and their contents into it.  You can then specify this as
the source to install from when you run the setup program.  Like with the CD-ROM 
installation, you'll only have to make the boot and root floppies.

To install from NFS, set up a similar directory on the NFS server you plan to
use, and then make sure the directory is exported.  If you're installing to
a laptop using PCMCIA ethernet, make sure to use the PCMCIA rootdisk.  It
contains special kernel modules to recognize PCMCIA devices.

Again, make sure you have a blank, formatted floppy ready to make your Linux
boot disk at the end of the installation. 

[NOTE]: You may install most software packages by typing "setup" on a
running system. If you reinstall the A series, or the Q series (which
replaces your kernel), be sure to run LILO or make a new boot disk using the
rescue disk. Also, if you reinstall some of the base packages you might need 
to reconfigure files in /etc or other places.  

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

This will take about 110 megabytes, so if you don't have that much space you'll
have to be selective about which disk sets to copy over.  You need at least the
A series to start with.  If you want to try to get your CD-ROM running once the
system is installed you can keep an eye on sunsite.unc.edu:/pub/Linux/kernel
for new kernels or kernel patches that support your CD-ROM drive.

Your packages are listed in /var/log/packages. Any of these packages may be
removed or reinstalled using "pkgtool".

Enjoy!

Patrick Volkerding
volkerdi@ftp.cdrom.com
volkerdi@mhd1.moorhead.msus.edu
