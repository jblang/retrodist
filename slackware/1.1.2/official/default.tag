a    *            SKP
a    base         ADD   # Sets up the basic directory structure and adds a few important
a    bin          ADD   # Binaries that go in /bin and /usr/bin.
a    bootutls     ADD   # Stephen Tweedie's bootutils package version 1.0
a    comms        REC   # Serial file-transfer and communication packages.
a    cpio         ADD   # The GNU cpio backup and archiving utility v. 2.3
a    devs         ADD   # This package creates special files in the /dev directory that
a    diff         ADD   # The GNU diff utilities - finds differences between files. (to make
a    e2fsbn       ADD   # Utilities for the second extended file system v. 0.4a
a    etc          ADD   # System configuration files that go into the /etc directory.
a    find         ADD   # GNU find 3.8
a    getty        OPT   # getty_ps 2.0.7c
a    grep         ADD   # GNU grep 2.0
a    gzip         ADD   # GNU zip compression utilities. (v. 1.2.4)
a    hdsetup      ADD   # The Slackware setup system v. 1.1.2
a    idekern      REC   # Linux kernel version .99 patch level 15, without SCSI support.
a    keytbls      OPT   # kbd 0.84
a    ksh          OPT   # pdksh 4.8
a    ldso         ADD   # ld.so 1.4.3, the dynamic linker/loader.
a    lilo         ADD   # Lilo 0.14
a    lpr          ADD   # BSD print spooling system.
a    passwd       ADD   # Password utilities, and account maintenance programs.
a    ps           ADD   # procps 0.92
a    scsikern     REC   # Linux kernel version .99 patch level 15, with SCSI support.
a    select       REC   # Selection 1.5
a    shellutl     ADD   # GNU shellutils 1.9.2
a    shlbsvga     ADD   # Shared library libsvga.so.1.0.9 (from svgalib 1.00)
a    shlibs       ADD   # The shared C libraries libc.so.4.5.19 and libm.so.4.5.19.
a    syslogd      ADD   # Sysklogd 1.1
a    sysvinit     ADD   # SysV style init v. 2.4
a    tar          ADD   # GNU tar 1.11.2
a    tcsh         OPT   # tcsh 6.04
a    textutl      ADD   # GNU textutil 1.9
a    util         ADD   # util-linux 1.5
a    zoneinfo     ADD   # Time zone utilities

ap   *            SKP
ap   bc           OPT   # GNU bc 1.02 - An arbitrary precision calculator language.
ap   english      OPT   # The International version of ispell (3.009)
ap   ghostscr     OPT   # GNU Ghostscript version 2.6.1 - (with fixes 01-04 applied).
ap   gonzo        OPT   # Sample users "gonzo", "snake", and "satan".
ap   gp9600       OPT   # This is a script that allows you to set your modem speed. If you do
ap   groff        REC   # GNU troff 1.08 document formatting system.
ap   gsfonts1     OPT   # Fonts for the Postscript interpreter.
ap   gsfonts2     OPT   # More fonts for the Postscript interpreter.
ap   ispell       OPT   # GNU ispell 4.0 (interactive spell checker)
ap   joe          OPT   # Joe text editor, version 1.0.8.
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.14.7)
ap   man          REC   # On-line manual pages.
ap   manpgs       REC   # Manpages 1.2
ap   quota        OPT   # quota-1.3 and acct-1.3.
ap   sc           OPT   # The 'sc' spreadsheet. (v. 6.21)
ap   termbin      OPT   # Term 1.12
ap   termsrc      OPT   # Term 1.12 source code
ap   workbone     OPT   # Workbone 0.1

d    *            SKP
d    binutils     ADD   # GNU binutils 1.9 Linux release 1
d    bison        REC   # GNU bison parser generator version 1.22.
d    byacc        REC   # Berkeley Yacc is an LALR(1) parser generator.  Berkeley Yacc
d    clisp        OPT   # A Common Lisp interpreter.
d    extralib     OPT   # Extra static libraries used for profiling and debugging. (v. 4.5.19)
d    f2c          OPT   # A Fortran-77 to C translator.
d    flex         ADD   # flex - fast lexical analyzer generator version 2.3.8
d    gcc          REC   # The GNU C compiler and support files (v. 2.5.8)
d    gdb          REC   # The GNU debugger. (v. 4.11)
d    gmake        ADD   # GNU Make version 3.69. Automates program compilation.
d    gxx          REC   # The GNU C++ compiler and support files (v. 2.5.8)
d    include      ADD   # Standard include files needed to compile C programs.  (v. 4.5.19)
d    kernel       REC   # Linux kernel source (0.99pl15)
d    libc         ADD   # Development libraries for the C compiler. (v. 4.5.19)
d    libgxx       REC   # GNU libg++-2.5.3
d    m4           REC   # GNU m4 1.1
d    man2         REC   # Man pages for Linux system calls. (from manpages-1.2)
d    man3         REC   # Man pages for the C library functions. (from manpages-1.2)
d    ncurses      REC   # A curses-compatible screen management library with color. (v. 1.8.1)
d    objc         OPT   # GNU compiler for the Objective-C language. (v. 2.5.8)
d    p2c          OPT   # A Pascal to C translator. (v. 1.19)
d    perl         OPT   # Larry Wall's interpreted systems language. (v. 4.0pl36)
d    pmake        ADD   # BSD 4.4 make. This may be required if you're going to port software
d    rcs          OPT   # GNU revision control system.  (v. 5.6)
d    svgalib      OPT   # Svgalib Super-VGA Graphics Library (v1.00)

e    *            SKP
e    elisp1       OPT   # Part one of the Lisp source files for Emacs 19.22.
e    elisp2       OPT   # Part two of the Lisp source files for Emacs 19.22.
e    elispc       REC   # These are compiled lisp files for GNU Emacs 19.22.
e    emac_nox     OPT   # A replacement /usr/bin/emacs-19.22 binary that is not compiled with
e    emacmisc     REC   # Miscellaneous files for emacs 19.22.
e    emacsbin     ADD   # The base binaries for the GNU Emacs editor/environment v. 19.22

f    *            SKP
f    manyfaqs     ADD   # A collection of frequently asked questions/answers on many subjects.

i    *            SKP
i    info1        ADD   # Part one of the info files collection.
i    info2        ADD   # Part two of the info files collection.
i    info3        ADD   # Part three of the info files collection.

iv   *            SKP
iv   doc31        OPT   # An X-windows based WYSIWYG editor that saves in TeX format.
iv   idraw        OPT   # A drawing program that saves in Postscript.
iv   ivincs       OPT   # include files for programming InterViews
iv   ivlibs31     OPT   # Libraries for programming InterViews.

libc *            SKP

n    *            SKP
n    cnews        OPT   # Controls the spooling and transmission of Usenet news.
n    deliver      OPT   # A small and simple program that delivers electronic mail once it
n    dip          OPT   # Source code for dip v.3.3.7 with Net2Debugged patches.
n    elm          OPT   # Menu-driven user mail program. (v. 2.4pl23)
n    mailx        REC   # The mailx mailer.
n    netcfg       REC   # "netconfig" is a script to help configure TCP/IP and mail on your
n    nn           OPT   # The 'nn' news reader. (v. 6.4.18)
n    pine         OPT   # Pine version 3.89
n    ppp          OPT   # ALPHA PPP for Linux, version 0.1.4/0.1.5
n    smail        REC   # Ian Kluft's Linux port of Smail 3.1.28.
n    tcpip        REC   # TCP/IP networking programs and support files.
n    tin          OPT   # The 'tin' news reader. (1.2pl2)
n    tracrout     OPT   # Source and executable of "traceroute", a utility that allows you to
n    trn          OPT   # A threaded news reader. (v. 2.5)
n    uucp         OPT   # Taylor UUCP 1.04 (configured for HoneyDanBer mode)

oi   *            SKP
oi   oidemos      ADD   # OI demo programs                                                 [OPT]
oi   oidoc        ADD   # OI documentation, ObjectBuilder documentation, COPYING, etc      [REC]
oi   oiinc        ADD   # OI include files                                                 [REQ]
oi   oilib        ADD   # Shared OI library (.so and .sa)                                  [REQ]
oi   oiman        ADD   # OI manual pages                                                  [OPT]
oi   oimisc       ADD   # OI configuration files, etc                                      [REQ]
oi   oistat       ADD   # Static OI library.                                               [OPT]
oi   uib          ADD   # ObjectBuilder binaries, config files and other programs          [REQ]

oop  *            SKP
oop  smaltalk     OPT   # GNU Smalltalk 1.1.1
oop  stix         OPT   # A Smalltalk interface to X11.

t    *            SKP
t    texams       ADD   # TeX fonts.
t    texbin       ADD   # TeX binaries.
t    texcm        ADD   # TeX fonts.
t    texcmpk      ADD   # TeX fonts.
t    texdoc       ADD   # TeX man pages.
t    texfont      ADD   # TeX fonts.
t    texlibib     ADD   # TeX bibliography macros.
t    texlibmc     ADD   # A library of TeX macros.
t    texlibms     ADD   # A library of TeX macros.
t    texnfss2     ADD   # TeX fonts.

tcl  *            SKP
tcl  blt          OPT   # This is the version 1.0 release of the blt library.  It is an
tcl  itcl         OPT   # [incr Tcl] - version 1.3
tcl  tcl          ADD   # The Tcl script language, version 7.3
tcl  tclx         OPT   # TclX - Extended Tcl: Extended command set for Tcl (v. 7.3a)
tcl  tk           REC   # The Tk toolkit for Tcl, version 3.6

u    *            SKP
u    kernel       ADD   # Source code for Linux 0.99.15, with the patches for the UMSDOS
u    umsfix       ADD   # Fixes for some of the problems introduced by using UMSDOS as the
u    umskern      ADD   # A kernel image with UMSDOS, and SCSI support.
u    umsprogs     ADD   # umssetup and umssync - utilities needed to maintain UMSDOS partitions.

x    *            SKP
x    fvwmicns     REC   # Color icons from xpm3icons.tar.Z, found in the /pub/X11/contrib
x    x_8514       REC   # An accelerated server for cards using IBM8514 chips.
x    x_mach32     REC   # An accelerated server for cards using Mach32 chips.
x    x_mach8      REC   # An accelerated server for cards using Mach8 chips.
x    x_mono       REC   # A Monochrome server.
x    x_s3         REC   # An accelerated server for cards using S3 chips.
x    x_svga       REC   # A SuperVGA server.
x    x_vga16      REC   # A server for 16 colour graphics modes. (Last one!)
x    xconfig      OPT   # A collection of 24 sample Xconfig files, some for tricky to configure
x    xf_bin       ADD   # Basic client binaries required for XFree86 2.0.
x    xf_cfg       ADD   # XDM configuration, chooser, and FVWM 1.20.
x    xf_doc       REC   # Documentation and release notes for XFree86 2.0.
x    xf_lib       ADD   # Dynamic libraries, bitmaps and minimal fonts for XFree86 2.0.
x    xfonts1      REC   # More fonts for X windows. (part one)
x    xfonts2      REC   # More fonts for X windows. (part two)
x    xlock        ADD   # A screensaver/locker for X. Includes the man page.
x    xman1        REC   # Man pages for programs that come with XFree86 2.0.
x    xpm          ADD   # The Xpm shared and static libraries, v. 3.3

xap  *            SKP
xap  gchess       OPT   # GNU chess (v. 4.00 patch level 62)
xap  ghstview     OPT   # Ghostview 1.5
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  libgr13      REC   # Shared graphics libraries with GIF, TIFF, JPEG support.
xap  seyon        OPT   # Seyon 2.14B.
xap  vgaset       REC   # Utility to help you configure your monitor for X more easily.
xap  workman      OPT   # Workman CD music player. Requires the XV series, but would have
xap  x3270        OPT   # x3270 3.0.1.3 - IBM host access tool.
xap  xfileman     OPT   # One of two file managers for X included with the Slackware
xap  xfm12        OPT   # xfm 1.2, an X windows filemanager.
xap  xgames       OPT   # A collection of games for X:
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
y    bsdgames     OPT   # Curtis Olson and Andy Tefft's port of the BSD games collection. (1.3)
y    tetris       OPT   # Tetris for terminals.
