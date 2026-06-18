a    *            SKP
a    base         ADD   # Sets up the basic directory structure and adds a few important
a    bin          ADD   # System utilities and programs, such as GNU fileutils 3.9,
a    bootutls     ADD   # Stephen Tweedie's bootutils package version 1.0
a    comms        REC   # Serial file-transfer and communication packages.
a    cpio         ADD   # The GNU cpio backup and archiving utility. (v. 2.3)
a    devs         ADD   # Device files that represent the system's hardware, found in /dev.
a    diff         ADD   # The GNU diff utilities - finds differences between files. (to make
a    e2fsbn       ADD   # Utilities for the second extended file system. (v. 0.4a)
a    etc          ADD   # System configuration files that belong in /etc
a    find         ADD   # GNU find 3.8
a    getty        ADD   # /etc/getty and /etc/uugetty. (v. 2.0.7b)
a    grep         ADD   # This is GNU grep 2.0, the "fastest grep in the west" (we hope).
a    gzip         ADD   # The GNU zip compression utilities. (v. 1.2.4)
a    idekern      REC   # Linux kernel version .99 patch level 14, without SCSI support.
a    keytbls      OPT   # Load and save keyboard mappings. Needed if you are not
a    ksh          OPT   # A public domain version of the Korn Shell with man-pages. (v. 4.8)
a    ldso         ADD   # ld.so 1.3, the dynamic linker/loader.
a    lilo         ADD   # The Linux Loader: boots Linux from your hard drive. (v. 0.13)
a    lpr          ADD   # Print spooling system.
a    passwd       ADD   # Password utilities, and account maintenance programs.
a    ps           ADD   # procps-0.8, utilities for displaying process and memory information.
a    scsikern     REC   # Linux kernel version .99 patch level 14, with SCSI support.
a    select       REC   # Selection (v. 1.5)
a    shellutl     ADD   # GNU shellutils-1.9
a    shlbsvga     ADD   # Shared library libsvga.so.1.0.3 (from svgalib 0.94)
a    shlibs       ADD   # The shared C libraries libc.so.4.4.4 and libm.so.4.4.4.
a    syslogd      ADD   # Sysklogd 1.0
a    sysvinit     ADD   # Version 2.4 of the System V compatible INIT programs.
a    tar          ADD   # GNU tar 1.11.2
a    tcsh         OPT   # Extended C shell (tcsh) version 6.04 and man-pages.
a    textutl      ADD   # GNU textutil-1.9
a    util         ADD   # Selected utilities from the packages util-bin-2.0.bin.tar.gz,
a    zoneinfo     ADD   # Allows you to configure your time zone. Look in /usr/lib/zoneinfo

ap   *            SKP
ap   bc           OPT   # GNU bc 1.02 - An arbitrary precision calculator language.
ap   english      OPT   # The International version of ispell (3.009)
ap   ghostscr     OPT   # GNU Ghostscript version 2.6.1 - (with fixes 01-04 applied).
ap   gonzo        OPT   # Sample users "gonzo", "snake", and "satan".
ap   gp9600       OPT   # Changes the default modem for speed from 2400 baud to 9600 baud.
ap   groff        OPT   # GNU troff 1.08 document formatting system.
ap   gsfonts1     OPT   # Fonts for the Postscript interpreter.
ap   gsfonts2     OPT   # More fonts for the Postscript interpreter.
ap   ispell       OPT   # GNU ispell 4.0 (interactive spell checker)
ap   joe          OPT   # joe text editor, version 1.0.8.
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.14.7)
ap   man          REC   # On-line manual pages.
ap   manpgs       REC   # Assorted man pages from manpages-1.0 that go in sections
ap   quota        OPT   # quota-1.2 and acct-1.1.
ap   sc           OPT   # The 'sc' spreadsheet. (v. 6.21)
ap   termbin      OPT   # The executable files and man pages for term 1.08, which
ap   termsrc      OPT   # SOURCE code for the TERM daemon which allows multiple
ap   workbone     OPT   # Workbone 0.1 text-based audio CD player.

cc   *            SKP
cc   gcc          OPT   # The GNU C compiler and support files (v. 2.5.2)

d    *            SKP
d    binutils     ADD   # C compiler utilities (ar, as86, gprof, strip...)
d    bison        REC   # GNU bison parser generator version 1.22.
d    byacc        REC   # Berkeley Yacc is an LALR(1) parser generator.  Berkeley Yacc
d    clisp        OPT   # A Common Lisp interpreter.
d    extralib     OPT   # Extra static libraries used for profiling and debugging. (v. 4.4.4)
d    f2c          OPT   # A Fortran-77 to C translator.
d    flex         ADD   # flex - fast lexical analyzer generator version 2.3.8
d    gcc          REC   # The GNU C compiler and support files (v. 2.4.5)
d    gdb          REC   # The GNU debugger. (v. 4.11)
d    gmake        ADD   # GNU Make version 3.69. Automates program compilation.
d    gxx          REC   # The GNU C++ compiler and support files (v. 2.4.5)
d    include      ADD   # Standard include files needed to compile C programs.  (v. 4.4.4)
d    kernel       REC   # Source code and include files for the Linux kernel. (0.99pl14)
d    libc         ADD   # Development libraries for the C compiler. (v. 4.4.4)
d    m4           REC   # This is release 1.1 of GNU m4, a program which copies its
d    man2         REC   # Man pages for Linux system calls. (from manpages-1.0)
d    man3         REC   # Man pages for the C library functions. (from manpages-1.0)
d    ncurses      REC   # A curses-compatible screen management library with color. (v. 1.8.1)
d    objc         OPT   # GNU compiler for the Objective-C language. (v. 2.4.5)
d    p2c          OPT   # A Pascal to C translator. (v. 1.19)
d    perl         OPT   # Larry Wall's interpreted systems language. (v. 4.0pl36)
d    pmake        ADD   # BSD 4.4 make. This may be required if you're going to port
d    rcs          OPT   # GNU revision control system.  (v. 5.6)
d    svgalib      OPT   # Svgalib Super-VGA Graphics Library (v0.94)

e    *            SKP
e    elisp1       OPT   # Part one of the Lisp source files for Emacs 19.22.
e    elisp2       OPT   # Part two of the Lisp source files for Emacs 19.22.
e    elispc       REC   # These are compiled lisp files for GNU Emacs 19.22.
e    emac_nox     OPT   # A replacement /usr/bin/emacs-19.22 binary that is not compiled with
e    emacmisc     REC   # Miscellaneous files for emacs 19.22.
e    emacsbin     ADD   # The base binaries for the GNU Emacs editor/environment v. 19.22

f    *            SKP
f    manyfaqs     ADD   # A collection of answers to frequently asked questions on many

iv   *            SKP
iv   doc31        OPT   # An X-windows based WYSIWYG editor that saves in TeX format.
iv   idraw        OPT   # A drawing program that saves in Postscript.
iv   ivincs       OPT   # include files for programming InterViews
iv   ivlibs31     OPT   # link libraries for programming InterViews.

n    *            SKP
n    cnews        OPT   # Controls the spooling and transmission of Usenet news.
n    deliver      OPT   # A small and simple program that delivers electronic mail once it
n    dip          OPT   # Source code for dip v.3.3.4a
n    elm          OPT   # Menu-driven user mail program. (v. 2.4pl23)
n    mailx        REC   # The mailx mailer.
n    netcfg       REC   # "netconfig" is a script to help configure TCP/IP and mail on
n    nn           OPT   # The 'nn' news reader. (v. 6.4.18)
n    pine         OPT   # Pine version 3.87
n    smail        REC   # Ian Kluft's Linux port of Smail 3.1.28.
n    tcpip        REC   # TCP/IP networking programs and support files. (Net-2)
n    tin          OPT   # The 'tin' news reader. (1.2pl2)
n    tracrout     OPT   # Source and executable of "traceroute", a utility that
n    trn          OPT   # A threaded news reader. (v. 2.5)
n    uucp         OPT   # Taylor UUCP 1.04 (configured for HoneyDanBer mode)

oop  *            SKP
oop  smaltalk     OPT   # GNU Smalltalk 1.1.1
oop  stix         OPT   # A Smalltalk interface to X11.

t    *            SKP
t    texbin       ADD   # TeX binaries                                                     [OPT]

tcl  *            SKP
tcl  blt          OPT   # This is the version 1.0 release of the BLT library.  It is an
tcl  itcl         OPT   # [incr Tcl] - version 1.3
tcl  tcl          ADD   # The TCL script language, version 7.3
tcl  tclx         OPT   # TclX - Extended Tcl: Extended command set for Tcl (v. 7.3a)
tcl  tk           REC   # The TK toolkit for TCL, version 3.6

x    *            SKP
x    fvwmicns     REC   # Color icons from xpm3icons.tar.Z, found in the /pub/X11/contrib
x    x_8514       REC   # An accelerated server for cards using IBM8514 chips.
x    x_mach32     REC   # An accelerated server for cards using Mach32 chips.
x    x_mach8      REC   # An accelerated server for cards using Mach8 chips.
x    x_mono       REC   # A Monochrome server.
x    x_s3         REC   # An accelerated server for cards using S3 chips.
x    x_svga       REC   # A SuperVGA server.
x    x_vga16      REC   # A server for 16 colour graphics modes. (Last one!)
x    xf_bin       ADD   # Basic client binaries required for XFree86 2.0.
x    xf_cfg       ADD   # XDM configuration, chooser, and FVWM.
x    xf_doc       REC   # Documentation and release notes for XFree86 2.0.
x    xf_lib       ADD   # Dynamic libraries, bitmaps and minimal fonts for XFree86 2.0.
x    xfonts1      REC   # More fonts for X windows. (part one)
x    xfonts2      REC   # More fonts for X windows. (part two)
x    xlock        ADD   # A screensaver/locker for X. Includes the man page.
x    xman1        REC   # Man pages for programs that come with XFree86 2.0.
x    xpm32g       ADD   # The Xpm shared and static libraries, v. 3.2g.

xap  *            SKP
xap  gchess       OPT   # GNU chess (v. 4.00 patch level 62)
xap  ghstview     OPT   # Ghostview 1.5
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  libgr13      REC   # Shared graphics libraries with GIF, TIFF, JPEG support.
xap  seyon        OPT   # A complete, full-featured telecommunications package for X.
xap  vgaset       REC   # Utility to help you configure your monitor for X more easily.
xap  workman      OPT   # Workman CD music player. Requires the XV series, but would have
xap  x3270        OPT   # x3270 3.0.1.3 - IBM host access tool.
xap  xfileman     OPT   # One of two file managers for X included with the Slackware
xap  xfm12        OPT   # xfm 1.2, an X windows filemanager.
xap  xgames       OPT   # A collection of X windows games (and a couple utilities):
xap  xspread      OPT   # An X windows spreadsheet, version 2.1.
xap  xv300        OPT   # XV 3.00 GIF/TIFF/JPEG/PostScript Image Viewer.
xap  xxgdb        OPT   # xxgdb-1.06.

xd   *            SKP
xd   xf_kit       OPT   # XFree86 2.0 Linkkit
xd   xf_pex       OPT   # XFree86 2.0 PEX libraries
xd   xf_prog      REC   # XFree86 2.0 Program Development Kit
xd   xkitlib1     OPT   # Libraries needed by the XFree86 2.0 Linkkit. (part one)
xd   xkitlib2     OPT   # Libraries needed by the XFree86 2.0 Linkkit. (part two)
xd   xman3        OPT   # Man pages for the X11 programming libraries.

xv   *            SKP
xv   xv32_a       OPT   # Static libraries for developing Xview applications. (v. 3.2)
xv   xv32_sa      OPT   # Libraries for developing Xview applications which use the shared
xv   xv32_so      ADD   # Shared libraries for Xview 3.2.
xv   xv32exmp     OPT   # Sample programs for Xview which demonstrate the Slingshot and UIT
xv   xvinc32      OPT   # Include files for Xview programming.
xv   xvmenus      ADD   # Menus and help files for the OpenLook Window Manager.
xv   xvol32       ADD   # Xview 3.2. Configuration files, programs, and documentation for

y    *            SKP
y    bsdgames     OPT   # Curtis Olson and Andy Tefft's port of the BSD games collection.
