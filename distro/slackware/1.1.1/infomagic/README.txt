This is Slackware Linux 1.1.1.

This version is not compatible with earlier releases of Slackware Linux, 
due to changes in the filesystem structure and the uids of standard users
and gids of standard groups. It should be compatible with future releases,
but installing over existing systems is still not going to be 'recommended'
until I can get all the bugs out of it. There still are some.

It does not include the new C libraries, since they are still in alpha
testing and have not been fully released. Also, it does not contain a full
release of gcc 2.5.x, since the c++ in that requires the new C libraries to
work correctly. These things will be incorporated eventually, but at some
point I have to release things as I have them.


This is what you'll find in the subdirectories below:

./bootdisk      Boot/install disks for 1.44M and 1.2M floppy drives. You will 
                need at least one boot/install system to install this software.
                See the README file in ./bootdisk for more information.

./a1 - ./a3     The base system. Enough to get up and running and have elvis
                and comm programs available. Based around the 0.99pl14 Linux
                kernel, and the new filesystem standard (FSSTND). 
                
                These disks are known to fit on 1.2M disks, although the rest 
                of Slackware won't. If you have only a 1.2M floppy, you can 
                still install the base system, download other disks you want 
                and install them from your hard drive. 

./ap1 - ./ap4   Various applications and add ons, such as the manual pages,
                groff, ispell (GNU and international versions), term, joe,
                jove, ghostscript, sc, bc, and the quota patches.

./cc1           GNU GCC 2.5.2. Does not work with C++, but may be useful for
                recompiling 0.99pl14+. Most people will probably not want to
                install this disk.

./d1 - ./d6     Program development. GCC/G++/Objective C 2.4.5, make (GNU and
                BSD), byacc and GNU bison, flex, the 4.4.4 C libraries, gdb,
                kernel source for 0.99pl14, SVGAlib, ncurses, clisp, f2c, p2c,
                m4, perl, rcs.

./e1 - ./e5     GNU Emacs 19.22.

./f1            A collection of FAQs and other documentation.

./n1 - ./n3     Networking. TCP/IP, UUCP, mailx, dip, deliver, elm, pine, 
                smail, cnews, nn, tin, trn.

./oop1          Object Oriented Programming. GNU Smalltalk 1.1.1, and the
                Smalltalk Interface to X. (STIX)

./q1 - ./q4     Alternate kernels and kernel source. Contains precompiled
                0.99pl13r and 0.99pl14a kernels, and kernel source for 
                0.99pl13, 0.99pl13r, and 0.99pl14a.

./tcl1 - ./tcl2 Tcl, Tk, TclX, blt, itcl. 

./y1            Games. The BSD games collection, and Tetris for terminals.

--------- X windows disks:

./x1 - ./x5     The base XFree86 2.0 system, with libXpm, fvwm 1.11, and xlock
                added.

./xap1 - ./xap2 X applications: X11 ghostscript, libgr13, seyon, workman, 
                xfilemanager, xv 3.00, GNU chess and xboard, xfm 1.2, 
                ghostview, and various X games.

./xd1 - ./xd3   X11 program development. X11 libraries, server linkkit, PEX
                support.

./xv1 - ./xv2   Xview 3.2 release 5. XView libraries, and the Open Look 
                virtual and non-virtual window managers.

./iv1 - ./iv2   Interviews libraries, include files, and the doc and idraw
                apps. These run unreasonably slow on my machine, but they 
                might still be worth looking at.

./oi1 - ./oi3   ParcPlace's Object Builder 2.0 and Object Interface Library
                4.0, generously made available for Linux developers according
                to the terms in the "copying" notice found in these
                directories.

./t1 - ./t3     TeX support. Since many people have asked about TeX, I borrowed
                the 3 TeX disks from SLS and went through them changing the
                filesystem structure somewhat and fixing permissions. You can
                take this as a sign that Slackware TeX support may continue to
                improve. :^)    These disks haven't changed all that much, but
                they're better than getting the stock SLS ones, and should be
                helpful for people accessing ftp sites or BBSs that do not 
                carry SLS.


Enjoy!

---
Patrick Volkerding
volkerdi@mhd1.moorhead.msus.edu
