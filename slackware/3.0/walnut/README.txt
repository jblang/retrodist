                  This is Slackware Linux 3.0.0 (ELF)
                  -----------------------------------


This version contains libc 5.0.9, Linux kernels 1.2.13 and 1.3.18 (plus source
for many other versions in the source tree, including version 0.01 :^), and
XFree86 3.1.2.  Everything possible has been recompiled to use the ELF binary
format, but full support has been retained for running and compiling the old
a.out binaries as well.

Mail here _pours_ in at high volume, but feel free to report any problems you
find. I can't promise a response but I *do* appreciate the help people offer
me in fixing problems.
-----------------------------------------------------------------------------

This is what you'll find in the subdirectories below (or in the case of the 
disk sets, in the ./slakware subdirectory):

./bootdsks.144, ./bootdsks.12, ./rootdsks:
                Boot/install disks for 1.44M and 1.2M floppy drives. You will 
                need at least one boot disk and one rootdisk to install this
                software. See the README files in these directories for more 
                information.

./a1 - ./a5     The base system. Enough to get up and running and have elvis
                and comm programs available. Based around the 1.2.13 Linux
                kernel, and concepts from the Linux filesystem standard. 
                
                These disks are known to fit on 1.2M disks, although the rest 
                of Slackware won't. If you have only a 1.2M floppy, you can 
                still install the base system, download other disks you want 
                and install them from your hard drive. 

./ap1 - ./ap5   Various applications and add ons, such as the manual pages,
                groff, ispell, term (and many TCP/IP programs ported to term),
                joe, jed, jove, ghostscript, sc, bc, ftape support, and the
                quota patches.

./d1 - ./d10    Program development. GCC/G++/Objective C 2.7.0, make (GNU and
                BSD), byacc and GNU bison, flex, the 5.0.9 C libraries, gdb,
                SVGAlib, ncurses, gcl (LISP), f2c, p2c, m4, perl, rcs.

./e1 - ./e6     GNU Emacs 19.29.

./f1 - ./f2     A collection of FAQs and other documentation.

./k1 - ./k5     Linux kernel source.  Source to the 1.2.13 and 1.3.20 Linux
                kernels.  NOTE:  The include files in the Linux kernel are
                needed to compile many Linux programs, so you should install
                the kernel source if you plan to compile programs from the net.

./n1 - ./n4     Networking. TCP/IP, UUCP, mailx, dip, PPP, deliver, elm, pine, 
                BSD sendmail, cnews, nn, tin, trn, inn.

./q1 - ./q15    This series contains extra kernels. I would imagine that most
                people will want to use a kernel from this series. These kernels
                contain drivers such as UMSDOS, PPP, drivers for SCSI,
                networking cards, and the following non-SCSI CD-ROMs: Mitsumi,
                Sony cdu31/33a, Sound Blaster Pro/Lasermate/Panasonic, Aztech,
                Okano, Wearnes, Orchid, Sony 535/531, and many IDE/ATAPI CD-ROM
                drives.

		NOTE: With the exception of the PS/2 mouse driver (and the 
                similar C&T 82C710 mouse (as on TI Travelmate) driver, there
                is NO busmouse support in any of the precompiled kernels. The
                drivers interact when you compile them all in, and I can't
                provide a whole new set of kernels for each type of busmouse.
                If you need these drivers, be sure to recompile your kernel.
                Some people take the menu that sets the /dev/mouse link to be
                an indication that their busmouse will work right out of the
                box. It's not, and it won't. 

./t1 - ./t9     NTeX Release 1.2.1 - NTeX is a very complete TeX distribution
                for Linux.  Thanks to Frank Langbein for contributing this!

./tcl1          Tcl, Tk. David Engel's port of the major Tcl packages to Linux,
                including ELF shared library support.

./y1 - ./y4     Games. The BSD games collection, Tetris for terminals, 
                Sasteroids, ID Software's DOOM for Linux (console and
                X versions), and Crack Dot Com's ABUSE for Linux (console
                and X versions).

./contrib       This is a new one, and probably long overdue. Now that the new
                Slackware release contains scripts capable of creating packages
                (installpkg/makepkg/explodepkg), I've added a directory for 
                user contributed packages. I've started it off with a dozen
                or so nice extra packages, just to give you the idea. 
                The contents of this directory can basically be considered 
                "as is", and subject to change without notice. There aren't
                any fancy install menus here, either. Just raw packages to
                install with pkgtool or installpkg.  If you've got a package
                to contribute, contact me.

--------------- Disks for the X window system:

./x1 - ./x16    The base XFree86 3.1.2 system, with libXpm, fvwm 1.23b, and 
                xlock added. Also includes xf86config, an XF86Config writing
                program - just tell it your video card, mouse, and monitor,
                and it will create your XF86Config file for you!

./xap1 - ./xap4 X applications: X11 ghostscript, libgr, seyon, workman, 
                xfilemanager, xv 3.10, GNU chess and xboard, xfm 1.3.2,
                ghostview, gnuplot, xpaint, xfractint, and various X games. 

./xd1 - ./xd3   X11 server linkkit, static libraries, and PEX support.

./xv1 - ./xv3   xview3.2p1-X11R6. XView libraries, and the Open Look 
                virtual and non-virtual window managers for XFree86.

==============================================================================

Installation notes for Slackware Linux 3.0.0:
--------------------------------------------
A more detailed description of the installation process may be found in the
file INSTALL.TXT, the "Installation-HOWTO", by Matt Welsh.


INSTALLATION DISKS:
------------------
You will need installation disks: a "bootkernel" disk and a "root/install" 
disk.

To make your bootkernel/rootdisk combination, you'll have to get a boot kernel
and root disk.  Bootkernels are in ./bootdsks.12 (for 1.2 meg drives) and 
./bootdsks.144 (for 1.44 meg drives).  Rootdisks are in ./rootdsks.  Use 'dd' 
or RAWRITE.EXE to write them to floppies.

  NOTE: When using dd to create the boot kernel disk or root disk on Suns and 
  possibly some other Unix workstations you must provide an appropriate block
  size.  This probably wouldn't hurt on other systems, either.  Here's an 
  example: 

  dd if=scsinet of=/dev/(rdf0, rdf0c, fd0, or whatever) obs=18k


DISK SETS:

If you're installing from CD-ROM, you don't need to make any disk sets.  Just
select the ones you want during the installation process.  However, if you're 
installing from floppy disk, you'll need to make the disk sets you wish to 
install on MS-DOS formatted disks.  The A disks will fit on 1.2 MB or 1.44 MB 
disks, but all other disk sets require 1.44 MB disks.  So, if you're installing
from floppy using a 1.2 MB drive, you'll only be able to install the A series 
at first.  Once your machine is running Linux the rest of the packages you need
can be installed from your hard drive.

These are the disk sets that are available to install:
------------------------------------------------------
      A   - Base Linux system (required)
      AP  - Various applications that do not need X
      D   - Program Development (C, C++, Kernel source, Lisp, Perl, etc.)
      E   - GNU Emacs 
      F   - FAQ lists 
      K   - Linux kernel source
      N   - Networking (TCP/IP, UUCP, Mail)
      Q   - All kinds of extra kernels 
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

If you want to install from your hard drive, just set up a directory on
your DOS, Linux, or OS/2 partition containing the the disk subdirectories
for the disk sets you want.  For example, if you wanted to install the A
series, you might make a SLACK directory on your DOS drive and copy the A1,
A2, A3, A4, and A5 directories and their contents into it.  You can then
specify this as the source to install from when you run the setup program.
Like with the CD-ROM installation, you'll only have to make the boot and
root floppies.

To install from NFS, set up a similar directory on the NFS server you plan
to use, and then make sure the directory is exported.  If you're installing
to a laptop using PCMCIA ethernet, make sure to use the PCMCIA rootdisk.
It contains special kernel modules to recognize PCMCIA devices.

Again, make sure you have a blank, formatted floppy ready to make your Linux
boot disk at the end of the installation. 

[NOTE]: You may install most software packages by typing "setup" on a
running system. If you reinstall the A series, or the Q series (which
replaces your kernel), be sure to run LILO or make a new boot disk using
the rescue disk. Also, if you reinstall some of the base packages you might
need to reconfigure files in /etc or other places.

WHAT IF MY CD-ROM IS NOT RECOGNIZED?

Don't panic -- you'll still be able to install Linux from your hard drive.
Sometimes new CD-ROM hardware comes out and doesn't work with Linux.  It
can take a while for Linux to support it because the Linux developers
sometimes aren't told about the hardware's introduction and don't hear
about it at all until people start sending email wondering why it doesn't
work.  The people making hardware almost always write a DOS driver before
releasing it, so the workaround is to copy the disk sets you want to your
DOS partition (under DOS) and then install them from there.  Here's how
you'd copy the disk sets to a C:\SLACK directory under DOS from a CD-ROM
drive on e:

C:\> MKDIR SLACK
C:\> CD SLACK
C:\SLACK> XCOPY E:\SLAKWARE\*.* . /S

This will take about 110 megabytes, so if you don't have that much space
you'll have to be selective about which disk sets to copy over.  You need
at least the A series to start with.  If you want to try to get your CD-ROM
running once the system is installed you can keep an eye on
sunsite.unc.edu:/pub/Linux/kernel for new kernels or kernel patches that
support your CD-ROM drive.

Your packages are listed in /var/log/packages. Any of these packages may be
removed or reinstalled using "pkgtool".

Enjoy!

Patrick Volkerding
volkerdi@ftp.cdrom.com
volkerdi@mhd1.moorhead.msus.edu
