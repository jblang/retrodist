a    *            SKP
a    base         ADD   # Sets up the basic directory structure and adds a few important
a    bash         ADD   # GNU bash-1.14
a    bin          ADD   # Binaries that go in /bin and /usr/bin.
a    bootutls     ADD   # Stephen Tweedie's bootutils package version 1.0
a    comms        REC   # Serial file-transfer and communication packages.
a    cpio         ADD   # The GNU cpio backup and archiving utility v. 2.3
a    devs         ADD   # This package creates special files in the /dev directory that
a    e2fsbn       ADD   # Utilities for the second extended file system v. 0.5a
a    etc          ADD   # System configuration files that go into the /etc directory.
a    find         ADD   # GNU find 3.8
a    getty        OPT   # getty_ps 2.0.7e
a    grep         ADD   # GNU grep 2.0
a    gzip         ADD   # GNU zip compression utilities. (v. 1.2.4)
a    hdsetup      ADD   # The Slackware setup/package maintenance system v. 2.0.0
a    idekern      REC   # Linux kernel version 1.0.9, without SCSI support.
a    keytbls      OPT   # kbd 0.87
a    ldso         ADD   # ld.so 1.4.4, the dynamic linker/loader.
a    lilo         ADD   # Lilo 0.14
a    lpr          ADD   # BSD print spooling system.
a    passwd       ADD
a    ps           ADD   # procps 0.95
a    scsikern     REC   # Linux kernel version 1.0.9, with SCSI + IDE support.
a    select       REC   # Selection 1.5
a    shellutl     ADD   # GNU shellutils 1.9.4
a    shlbsvga     ADD   # Shared library libsvga.so.1.1.7 (from svgalib 1.11)
a    shlibs       ADD   # The shared C libraries libc.so.4.5.26 and libm.so.4.5.26.
a    syslogd      ADD   # Sysklogd 1.2
a    sysvinit     ADD   # SysV style init v. 2.4
a    tar          ADD   # GNU tar 1.11.2
a    tcsh         OPT   # tcsh 6.04
a    textutl      ADD   # GNU textutil 1.9
a    util         ADD   # util-linux 1.6
a    zoneinfo     ADD   # Time zone utilities

ap   *            SKP
ap   ash          OPT   # Kenneth Almquist's ash shell.
ap   bc           OPT   # GNU bc 1.02 - An arbitrary precision calculator language.
ap   diff         REC   # GNU diffutils-2.6
ap   english      OPT   # The International version of ispell (3.009)
ap   ftape        OPT   # ftape 0.9.9d, 0.9.10
ap   ghostscr     OPT   # GNU Ghostscript version 2.6.1 - (with fixes 01-04 applied).
ap   gonzo        OPT   # Sample users "gonzo", "snake", and "satan".
ap   gp9600       OPT   # This is a script that allows you to set your modem speed. If you do
ap   groff        REC   # GNU troff 1.09 document formatting system.
ap   gsfonts1     OPT   # Fonts for the Ghostscript interpreter/previewer.
ap   gsfonts2     OPT   # More fonts for the Ghostscript interpreter/previewer.
ap   ispell       OPT   # GNU ispell 4.0 (interactive spell checker)
ap   jed          OPT   # John E. Davis's JED 0.96 editor.
ap   joe          OPT   # Joe text editor, version 1.0.8.
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.14.7)
ap   man          REC   # On-line manual pages.
ap   manpgs       REC   # Manpages 1.2
ap   mt_st        OPT   # mt-st-0.1 - controls magnetic tape drive operation
ap   quota        OPT   # quota-1.33.
ap   sc           OPT   # The 'sc' spreadsheet. (v. 6.21)
ap   sudo         OPT   # sudo 1.2
ap   termbin      OPT   # Term 1.14
ap   termnet      OPT   # Network utilities for term
ap   termsrc      OPT   # Term 1.14 source code
ap   texinfo      REC   # GNU texinfo-3.1
ap   vim          OPT   # Version 2.0 of Vim: Vi IMproved
ap   workbone     OPT   # Workbone 0.1
ap   zsh          OPT   # zsh version 2.4

d    *            SKP
d    binutils     ADD   # GNU binutils 1.9 (linux-binutils-1.0)
d    bison        REC   # GNU bison parser generator version 1.22.
d    byacc        REC   # Berkeley Yacc is an LALR(1) parser generator.  Berkeley Yacc
d    clisp        OPT   # A Common Lisp interpreter.
d    extralib     OPT   # Extra static libraries used for profiling and debugging. (v. 4.5.26)
d    f2c          OPT   # A Fortran-77 to C translator.
d    flex         ADD   # flex - fast lexical analyzer generator version 2.4.6
d    gcc          REC   # The GNU C compiler and support files (v. 2.5.8)
d    gdb          REC   # The GNU debugger. (v. 4.12)
d    gxx          REC   # The GNU C++ compiler and support files (v. 2.5.8)
d    include      ADD   # Standard include files needed to compile C programs.  (v. 4.5.26)
d    kernel       REC   # Linux kernel source version 1.0.9
d    libc         ADD   # Development libraries for the C compiler. (v. 4.5.26)
d    libgxx       REC   # GNU libg++-2.5.3, Linux release 2
d    m4           REC   # GNU m4 1.1
d    man2         REC   # Man pages for Linux system calls. (from manpages-1.2)
d    man3         REC   # Man pages for the C library functions. (from manpages-1.2)
d    ncurses      REC   # A curses-compatible screen management library with color. (v. 1.8.5)
d    objc         OPT   # GNU compiler for the Objective-C language. (v. 2.5.8)
d    p2c          OPT   # A Pascal to C translator. (v. 1.19)
d    perl         OPT   # Larry Wall's interpreted systems language. (v. 4.0pl36)
d    pmake        ADD   # BSD 4.4 make. This may be required if you're going to port software
d    rcs          OPT   # GNU revision control system.  (v. 5.6)
d    svgalib      OPT   # Svgalib Super-VGA Graphics Library (v1.11)
d    tools        OPT   # tools 2.11

e    *            SKP
e    elisp1       OPT   # Part one of the Lisp source files for Emacs 19.25.
e    elisp2       OPT   # Part two of the Lisp source files for Emacs 19.25.
e    elispc       REC   # These are compiled lisp files for GNU Emacs 19.25.
e    emac_nox     OPT   # A replacement /usr/bin/emacs-19.25 binary that is not compiled with
e    emacmisc     REC   # Miscellaneous files for emacs 19.25.
e    emacsbin     ADD   # GNU Emacs 19.25

f    *            SKP
f    manyfaqs     ADD   # A collection of frequently asked questions/answers on many subjects.

i    *            SKP
i    info1        ADD   # Part one of the info files collection.
i    info2        ADD   # Part two of the info files collection.

iv   *            SKP
iv   iv_bin       ADD   # Binaries and miscellaneous files for InterViews 3.1
iv   iv_docs      REC   # Documentation files for InterViews 3.1.
iv   libiv_sa     OPT   # Shared library stubs and include files for InterViews 3.1.
iv   libiv_so     ADD   # Shared InterViews 3.1 libraries.

n    *            SKP
n    cnews        OPT   # Controls the spooling and transmission of Usenet news.
n    deliver      OPT   # A small and simple program that delivers electronic mail once it
n    elm          OPT   # Menu-driven user mail program. (v. 2.4pl23)
n    inn_pkg      OPT   # INN 1.4
n    lynx         OPT   # Lynx 2.2
n    mailx        REC   # BSD mailx 5.5.
n    netcfg       REC   # "netconfig" is a script to help configure TCP/IP and mail on your
n    nn           OPT   # The 'nn' news reader. (v. 6.4.18)
n    pine         OPT   # Pine version 3.89
n    ppp          OPT   # PPP for Linux, version 2.1.2a
n    smail        REC   # Ian Kluft's Linux port of Smail 3.1.28.
n    tcpip        REC   # TCP/IP networking programs and support files, with the net-0.32d
n    tin          OPT   # The 'tin' news reader. (1.2pl2)
n    trn          OPT   # A threaded news reader. (v. 3.4.1)
n    uucp         OPT   # Taylor UUCP version 1.05

ncr  *            SKP
ncr  ncr_inc3     REC   # Include files for the 1.1.19+NCR53c810 SCSI PCI driver Linux kernel.
ncr  ncr_krn3     OPT   # Linux kernel source 1.1.19 with NCR53c810 and Trantor T128 drivers.
ncr  ncrkern3     ADD   # Linux 1.1.19 kernel with NCR53c810 and Trantor T128 drivers.

oop  *            SKP
oop  smaltalk     OPT   # GNU Smalltalk 1.1.1
oop  stix         OPT   # A Smalltalk interface to X11.

q    *            SKP
q    cdu31a       REC   # Linux kernel version 1.1.18, with SCSI+IDE+Sony CDU31A CD support.
q    ftape18      REC   # ftape 1.12
q    i1_1_18      OPT   # Include files for the Linux 1.1.18 kernel.
q    idekern      REC   # Linux kernel version 1.1.18, without SCSI support.
q    ifs          OPT   # IFS (Inheriting File System) 5.1 utilities and kernel patch.
q    mitsumi      REC   # Linux kernel version 1.1.18, with SCSI+IDE+ Unifix Mitsumi CD driver.
q    sbpcd        REC   # Linux kernel version 1.1.18, with SCSI+IDE+SoundBlaster Pro CD
q    scsikern     REC   # Linux kernel version 1.1.18, with SCSI + IDE support.
q    sony535      REC   # Linux kernel version 1.1.18, with SCSI+IDE+Sony 535/531 CD support.
q    v1_1_18      OPT   # Linux kernel source version 1.1.18

t    *            SKP
t    dvi2xx       ADD   # The dvi2xx family consists of the following programs:
t    gentle       ADD   # A Gentle Introduction to TeX
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
tcl  blt          OPT   # This is the version 1.6 release of the blt library.  It is an
tcl  itcl         OPT   # [incr Tcl] - version 1.3
tcl  tcl          ADD   # The Tcl script language, version 7.3
tcl  tclx         OPT   # TclX - Extended Tcl: Extended command set for Tcl (v. 7.3a)
tcl  tk           REC   # The Tk toolkit for Tcl, version 3.6

u    *            SKP
u    loadlin      ADD   # LOADLIN v1.4
u    umsfix       ADD   # Fixes for some of the problems introduced by using UMSDOS as the
u    umsprogs     ADD   # umsdos_progs 0.3a

x    *            SKP
x    config86     REC   # Steven T Zwaska's ConfigXF86 XFree86 Xconfig generation script.
x    fnt100_1     OPT   # 100-dpi screen fonts (part one)
x    fnt100_2     OPT   # 100-dpi screen fonts (part two)
x    fntbig1      OPT   # Large Kanji and other fonts (part one)
x    fntbig2      OPT   # Large Kanji and other fonts (part two)
x    fvwmicns     REC   # Color icons from xpm3icons.tar.Z, found in the /pub/X11/contrib
x    speedo       OPT   # Scaled fonts (Speedo)
x    x_8514       REC   # An accelerated server for cards using IBM8514 chips.
x    x_mach32     REC   # An accelerated server for cards using Mach32 chips.
x    x_mach8      REC   # An accelerated server for cards using Mach8 chips.
x    x_mono       REC   # A Monochrome server.
x    x_s3         REC   # An accelerated server for cards using S3 chips.
x    x_svga       REC   # A SuperVGA server.
x    x_vga16      REC   # A server for 16 colour EGA/VGA graphics modes.
x    xconfig      OPT   # A collection of 24 sample Xconfig files, some for tricky to configure
x    xf_bin       ADD   # Basic client binaries required for XFree86 2.1.1.
x    xf_cfg       ADD   # XDM configuration, chooser, and FVWM 1.21c.
x    xf_doc       REC   # Documentation and release notes for XFree86 2.1.1.
x    xf_lib       ADD   # Dynamic libraries and configuration files for XFree86 2.1.1.
x    xfnt         ADD   # Fonts for the X window system.
x    xfnt75       REC   # 75dpi Fonts for the X window system.
x    xinclude     ADD   # Header files for X11 programming.
x    xlock        ADD   # xlock version 23.21 patchlevel 2.3
x    xman1        REC   # Man pages for programs that come with XFree86 2.1.1.
x    xpm          ADD   # The Xpm shared and static libraries, v. 3.3

xap  *            SKP
xap  gchess       OPT   # GNU chess (v. 4.00 patch level 69)
xap  ghstview     OPT   # Ghostview 1.5
xap  gnuplot      OPT   # gnuplot 3.5
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  libgr        REC   # libgr-1.3
xap  seyon        OPT   # Seyon 2.14c.
xap  vgaset       REC   # Utility to help you configure your monitor for X more easily.
xap  workman      OPT   # WorkMan-1.2.2a
xap  x3270        OPT   # x3270 3.0.1.3 - IBM host access tool.
xap  xfig         OPT   # Xfig/Transfig 2.1.8
xap  xfileman     OPT   # xfilemanager 0.5
xap  xfm12        OPT   # xfm 1.2, a filemanager for X.
xap  xfract       OPT   # xfractint-2.03
xap  xgames       OPT   # A collection of games for X:
xap  xgrabsc      OPT   # Xgrabsc and Xgrab 2.3
xap  xpaint       OPT   # XPaint 2.1
xap  xspread      OPT   # An X windows spreadsheet, version 2.1.
xap  xv           OPT   # John Bradley's XV 3.01 GIF/TIFF/JPEG/PostScript image viewer.
xap  xxgdb        OPT   # xxgdb-1.08.

xd   *            SKP
xd   pex5inc      OPT   # PEX5 include files, used with the PEX extensions package.
xd   xf_kit       OPT   # XFree86 2.1.1 Linkkit
xd   xf_kit2      OPT   # XFree86 2.1.1 Linkkit, part 2 (driver libraries)
xd   xf_pex       OPT   # XFree86 2.1.1 PEX distribution
xd   xman3        OPT   # Man pages for the X11 programming libraries.
xd   xstatic      OPT   # Static versions of the X libraries.

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
y    sastroid     OPT   # Sasteroids 1.3
y    tetris       OPT   # Tetris for terminals.
