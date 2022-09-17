This is Slackware Linux 2.0.0.

This version contains libc 4.5.26, Linux kernel 1.0.9 and 1.1.18 (plus source
for many other versions in the source tree, including version 0.01 :^), and
XFree86 2.1.1.

I'm still (nearly always :^) behind in my mail, but feel free to report any
problems you find. I can't promise a response but I *do* appreciate the help
people offer me in fixing problems.

This is what you'll find in the subdirectories below:

./bootdsks.144, ./rootdsks.144, bootdsks.12, rootdsks.12:
                Boot/install disks for 1.44M and 1.2M floppy drives. You will 
                need at least one boot disk and one rootdisk to install this
                software. See the README files in these directories for more 
                information.

./a1 - ./a3     The base system. Enough to get up and running and have elvis
                and comm programs available. Based around the 1.0.9 Linux
                kernel, and concepts from the new filesystem standard (FSSTND). 
                
                These disks are known to fit on 1.2M disks, although the rest 
                of Slackware won't. If you have only a 1.2M floppy, you can 
                still install the base system, download other disks you want 
                and install them from your hard drive. 

./ap1 - ./ap4   Various applications and add ons, such as the manual pages,
                groff, ispell (GNU and international versions), term, joe, jed,
                jove, ghostscript, sc, bc, ftape support, and the quota patches.

./d1 - ./d6     Program development. GCC/G++/Objective C 2.5.8, make (GNU and
                BSD), byacc and GNU bison, flex, the 4.5.26 C libraries, gdb,
                kernel source for Linux 1.0.9. SVGAlib, ncurses, clisp, f2c, 
                p2c, m4, perl, rcs, dll tools.

./e1 - ./e5     GNU Emacs 19.24.

./f1            A collection of FAQs and other documentation.

./i1 - ./i2     Info pages for GNU software, readable by 'info', Jed, or Emacs.

./n1 - ./n3     Networking. TCP/IP, UUCP, mailx, dip, deliver, elm, pine, 
                smail, cnews, nn, tin, trn, inn.

./oop1          Object Oriented Programming. GNU Smalltalk 1.1.1, and the
                Smalltalk Interface to X. (STIX)

./q1 - ./q4     This series contains extra kernels and kernel source. I would
                imagine that most people will want to use a kernel from this 
                series. It contains source for Linux 1.1.18 with the UMSDOS 
                filesystem already built in, as well as PPP support. There are
                several precompiled kernels provided as well.  All of these 
                were built from the 1.1.18 source provided, and contain UMSDOS,
                PPP, drivers for SCSI, IFS, networking cards, and the following
                non-SCSI CD-ROMs: Mitsumi, Sony cdu31/33a, Sound Blaster 
                Pro/Lasermate/Panasonic, and Sony 535/531.

		NOTE: With the exception of the PS/2 mouse driver (and the 
                similar C&T 82C710 mouse (as on TI Travelmate) driver, there
                is NO busmouse support in any of the precompiled kernels. The
                drivers interact when you compile them all in, and I can't
                provide a whole new set of kernels for each type of busmouse.
                If you need these drivers, be sure to recompile your kernel.
                Some people take the menu that sets the /dev/mouse link to be
                an indication that their busmouse will work right out of the
                box. It's not, and it won't. 

./tcl1 - ./tcl2 Tcl, Tk, TclX, blt, itcl.

./u1            This disk is required when installing Linux with the UMSDOS
                filesystem, and should only be installed when using UMSDOS for
                your root filesystem. For those who aren't familiar with it, 
                UMSDOS is a filesystem which runs on top of an MS-DOS filesystem
                and allows long filenames, hard and symbolic links, and the
                other features needed to support Linux. Although not as fast as
                a native Linux filesystem, it's great for trying out Linux, and
		not bad on a system with a smaller hard drive that must also 
		run DOS.

./y1            Games. The BSD games collection, Tetris for terminals, and
                Sasteroids.

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

./x1 - ./x8     The base XFree86 2.1.1 system, with libXpm, fvwm 1.21c, and 
                xlock added. Also includes a beta version of an Xconfig-writing
                program - just tell it your video card, mouse, and monitor, and
                it will create your Xconfig file for you!

./xap1 - ./xap3 X applications: X11 ghostscript, libgr13 (newly compiled with
                working shared stubs), seyon, workman, xfilemanager, xv 3.01, 
                GNU chess and xboard, xfm 1.2, xgrabsc, ghostview, gnuplot,
                xpaint, xfig/transfig, xfractint, and various X games.

./xd1 - ./xd3   X11 server linkkit, PEX support, and X11 programming man pages.

./xv1 - ./xv2   Xview 3.2 release 5. XView libraries, and the Open Look 
                virtual and non-virtual window managers.

./iv1 - ./iv2   InterViews libraries, include files, 'doc', 'idraw', and other
                applications and utilities from the InterViews 3.1 distribution.
                Now uses shared libraries.

./oi1 - ./oi3   ParcPlace's Object Builder 2.0 and Object Interface Library
                4.0, generously made available for Linux developers according
                to the terms in the "copying" notice found in these
                directories. 

		NOTE: These haven't worked since we stopped using libc.so.4.4.4,
		so they've been placed in the oipatches directory in the source
                tree. You can either try applying the patches in that directory
                to attempt to use OI with recent libs (this didn't work for me),
                or downgrade your libraries to 4.4.4 if you *really* want to use
                OI. There is a libc-4.4.4 downgrade package in the libc-4.4.4
                directory. I don't suggest using it, but it does work.

./t1 - ./t5     TeX support. This is the LaTeX2e release ported by W. Woody Jin.


Enjoy!
---
Patrick Volkerding
volkerdi@mhd1.moorhead.msus.edu
