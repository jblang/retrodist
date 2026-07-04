This is Slackware Linux 2.2.0.

This version contains libc 4.6.27, Linux kernel 1.2.1 (plus source for many
other versions in the source tree, including version 0.01 :^),
and XFree86 3.1.1.

Mail here _pours_ in at high volume, but feel free to report any problems you
find. I can't promise a response but I *do* appreciate the help people offer
me in fixing problems.

This is what you'll find in the subdirectories below (or in the case of the 
installation disks, in the ./slakware subdirectory):

./bootdsks.144, ./rootdsks.144, bootdsks.12, rootdsks.12:
                Boot/install disks for 1.44M and 1.2M floppy drives. You will 
                need at least one boot disk and one rootdisk to install this
                software. See the README files in these directories for more 
                information.

./a1 - ./a4     The base system. Enough to get up and running and have elvis
                and comm programs available. Based around the 1.2.1 Linux
                kernel, and concepts from the Linux filesystem standard. 
                
                These disks are known to fit on 1.2M disks, although the rest 
                of Slackware won't. If you have only a 1.2M floppy, you can 
                still install the base system, download other disks you want 
                and install them from your hard drive. 

./ap1 - ./ap5   Various applications and add ons, such as the manual pages,
                groff, ispell, term (and many TCP/IP programs ported to term),
                joe, jed, jove, ghostscript, sc, bc, ftape support, and the
                quota patches.

./d1 - ./d9     Program development. GCC/G++/Objective C 2.6.3, make (GNU and
                BSD), byacc and GNU bison, flex, the 4.6.27 C libraries, gdb,
                kernel source for Linux 1.1.94. SVGAlib, ncurses, clisp, f2c, 
                p2c, m4, perl, rcs, dll tools.

./e1 - ./e5     GNU Emacs 19.28.

./f1 - ./f2     A collection of FAQs and other documentation.

./i1 - ./i2     Info pages for GNU software, readable by 'info', Jed, or Emacs.

./n1 - ./n4     Networking. TCP/IP, UUCP, mailx, dip, PPP, deliver, elm, pine, 
                BSD sendmail, cnews, nn, tin, trn, inn.

./oop1          Object Oriented Programming. GNU Smalltalk 1.1.1, and the
                Smalltalk Interface to X. (STIX)

./q1 - ./q9     This series contains extra kernels. I would imagine that most
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

./t1 - ./t10    NTeX Release 1.2.1 - NTeX is a very complete TeX distribution
                for Linux.  Thanks to Frank Langbein for contributing this!

./tcl1 - ./tcl2 Tcl, Tk, TclX, blt, itcl. David Engel's port of the major
                Tcl packages to Linux, including shared library support.

./y1 - ./y3     Games. The BSD games collection, Tetris for terminals, 
                Sasteroids, and ID Software's DOOM for Linux (console and
                X versions)

./contrib       This is a new one, and probably long overdue. Now that the new
                Slackware release contains scripts capable of creating packages
                (installpkg/makepkg/explodepkg), I've added a directory for user
                contributed packages. I've started it off with a dozen or so
                nice extra packages, just to give you the idea. The contents of
                this directory can basically be considered "as is", and subject
                to change without notice. There aren't any fancy install menus
                here, either. Just raw packages to install with pkgtool or
                installpkg.  If you've got a package to contribute, contact me.

--------- Disks for the X window system:

./x1 - ./x14    The base XFree86 3.1.1 system, with libXpm, fvwm 1.23b, and 
                xlock added. Also includes a beta version of an XF86Config-
                writing program - just tell it your video card, mouse, and
                monitor, and it will create your XF86Config file for you!

./xap1 - ./xap3 X applications: X11 ghostscript, libgr13 (newly compiled with
                working shared stubs), seyon, workman, xfilemanager, xv 3.10, 
                GNU chess and xboard, xfm 1.3, ghostview, gnuplot, xpaint, 
                xfractint, and various X games. (No, Xfig isn't gone.  It has
                been moved to the T (TeX) series, and the app-defaults bug has
                been fixed.)  This disk set has been completely recompiled for
                XFree86 3.1.

./xd1 - ./xd3   X11 server linkkit, static libraries, and PEX support.

./xv1 - ./xv3   xview3.2p1-X11R6. XView libraries, and the Open Look 
                virtual and non-virtual window managers for XFree86 3.1.1.

./iv1           InterViews libraries, 'doc', 'idraw', and other applications
                and utilities from the InterViews 3.1 distribution.

Enjoy!
---
Patrick Volkerding
volkerdi@mhd1.moorhead.msus.edu
