a    *            SKP
a    aaa_base     ADD   # Basic Linux filesystem package.
a    aoutlibs     ADD   # a.out shared libraries:
a    bash         ADD   # GNU bash-1.14.7
a    bin          ADD   # Binaries that go in /bin and /usr/bin.
a    bsdlpr       REC   # BSD lpr-5.9-13
a    cpio         ADD   # The GNU cpio backup and archiving utility v. 2.4.2
a    devs         ADD   # Device files.
a    e2fsbn       ADD   # Utilities for the second extended file system v. 1.10
a    elflibs      ADD   # ELF shared libraries.
a    etc          ADD   # System configuration files that go into the /etc directory.
a    find         ADD   # GNU findutils-4.1
a    getty        OPT   # getty_ps 2.0.7i
a    gpm          REC   # General purpose mouse support v1.10
a    grep         ADD   # GNU grep 2.0
a    gzip         ADD   # GNU zip compression utilities. (v. 1.2.4)
a    hdsetup      ADD   # The Slackware setup/package maintenance system v. 3.3.0
a    ibcs2        OPT   # Intel Binary Compatibility Specification module
a    ide          REC   # Linux kernel version 2.0.30, without SCSI support.
a    kbd          OPT   # kbd 0.94
a    ldso         ADD   # ld.so 1.9.5, the dynamic linker/loader.
a    less         ADD   # less-332
a    lilo         ADD   # LILO 19
a    loadlin      REC   # LOADLIN v1.6
a    minicom      REC   # Minicom 1.75
a    modules      ADD   # Linux kernel modules for 2.0.30.
a    pcmcia       OPT   # pcmcia-cs-2.9.6
a    pnp          OPT   # isapnptools-1.10
a    ps           ADD   # procps 1.01
a    scsi         REC   # Linux kernel version 2.0.30, with SCSI support.
a    scsimods     OPT   # Linux SCSI kernel modules for 2.0.30.
a    sh_utils     ADD   # GNU sh-utils-1.16
a    shadow       ADD   # Shadow password suite.
a    sysklogd     ADD   # Sysklogd 1.3
a    sysvinit     ADD   # SysVinit v. 2.69
a    tar          ADD   # GNU tar 1.12
a    tcsh         OPT   # tcsh 6.07
a    txtutils     ADD   # GNU textutils-1.22
a    umsprogs     ADD   # umsdos_progs 0.9
a    util         ADD   # util-linux 2.6 - A huge collection of essential utilities.
a    zoneinfo     ADD   # Time zone utilities

ap   *            SKP
ap   ash          OPT   # Kenneth Almquist's ash shell.
ap   bc           OPT   # GNU bc 1.04 - An arbitrary precision calculator language.
ap   diff         REC   # GNU diffutils-2.7
ap   ghostscr     REC   # Ghostscript version 3.33
ap   groff        ADD   # GNU troff 1.10 document formatting system.
ap   gsfonts1     REC   # Fonts for the Ghostscript interpreter/previewer, part one.
ap   gsfonts2     REC   # Fonts for the Ghostscript interpreter/previewer, part two.
ap   gsfonts3     REC   # Fonts for the Ghostscript interpreter/previewer, part three.
ap   ispell       OPT   # ispell-3.1.20
ap   jed          OPT   # John E. Davis's JED 0.97-14 editor.
ap   joe          OPT   # Joe text editor, 2.8.
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.14.10)
ap   jpeg         OPT   # Independent JPEG Group's JPEG software version 6a.
ap   manpgs       REC   # Man-pages 1.16 (on-line Linux documentation)
ap   mc           OPT   # Midnight Commander version 4.0.
ap   mt_st        OPT   # mt-st-0.4 - controls magnetic tape drive operation
ap   quota        OPT   # Linux disk quota utilities (1.51)
ap   sc           OPT   # The 'sc' spreadsheet. (v. 6.21)
ap   sudo         OPT   # sudo 1.2
ap   texinfo      REC   # GNU texinfo-3.9
ap   vim          OPT   # Version 4.6 of Vim: Vi IMproved
ap   workbone     OPT   # Workbone 2.3
ap   zsh          OPT   # zsh version 3.0.3

d    *            SKP
d    binutils     ADD   # GNU binutils 2.8.1.0.1
d    bison        REC   # GNU bison parser generator version 1.25.
d    byacc        OPT   # Berkeley Yacc is an LALR(1) parser generator.  Berkeley Yacc
d    flex         ADD   # flex - fast lexical analyzer generator version 2.5.4
d    g77          OPT   # GNU Fortran-77 compiler, version 0.5.20.
d    gcc2722      ADD   # The GNU C compiler and support files for ELF (v. 2.7.2.2)
d    gccaout      OPT   # The GNU C compiler and support files for the a.out format.
d    gcl          OPT   # GNU Common LISP 2.2.1
d    gdb          OPT   # The GNU debugger. (v. 4.16)
d    gmake        ADD   # GNU make utility 3.74.
d    gxx2722      REC   # The GNU C++ compiler and support files for ELF (v. 2.7.2.2)
d    gxxaout      OPT   # The GNU C++ compiler and support files for the a.out format.
d    libaout      REC   # Libraries for the old a.out binary format. (libc-4.7.6)
d    libc         ADD   # Development libraries for the C compiler.
d    libcinfo     OPT   # C library documentation
d    libgxx       REC   # GNU libg++-2.7.2.1
d    linuxinc     ADD   # Linux 2.0.30 kernel include files
d    m4           ADD   # GNU m4 1.4
d    man2         REC   # Man pages for Linux system calls. (from manpages-1.16)
d    man3         REC   # Man pages for the C library functions. (from manpages-1.16)
d    ncurses      REC   # A curses-compatible screen management library with color. (v. 1.9.9e)
d    objc2722     OPT   # GNU compiler for the Objective-C language (v. 2.7.2.2)
d    objcaout     OPT   # The GNU Objective-C compiler and support files for the a.out format.
d    p2c          OPT   # A Pascal to C translator. (v. 1.19)
d    perl1        OPT   # Larry Wall's interpreted systems language, part one. (v. 5.004)
d    perl2        OPT   # Larry Wall's interpreted systems language, part two. (v. 5.004)
d    perl3        OPT   # Larry Wall's interpreted systems language, part three. (v. 5.004)
d    pmake        ADD   # BSD 4.4 make.
d    rcs          OPT   # GNU revision control system.  (v. 5.7)
d    strace       OPT   # strace 3.0 - traces system calls and signals.
d    svgalib      OPT   # Svgalib Super-VGA Graphics Library 1.2.10
d    terminfo     OPT   # Complete /usr/lib/terminfo database.
d    tools        OPT   # tools 2.17

e    *            SKP
e    elisp1       OPT   # Part one of the Lisp source files for Emacs 19.34.
e    elisp2       OPT   # Part two of the Lisp source files for Emacs 19.34.
e    elisp3       OPT   # Part three of the Lisp source files for Emacs 19.34.
e    elisp4       OPT   # Part four of the Lisp source files for Emacs 19.34.
e    elispc1      REC   # These are compiled lisp files for GNU Emacs 19.34 (part one).
e    elispc2      REC   # These are compiled lisp files for GNU Emacs 19.34 (part two).
e    elispc3      REC   # These are compiled lisp files for GNU Emacs 19.34 (part three).
e    emac_nox     OPT   # A replacement /usr/bin/emacs-19.34 binary that is not compiled with
e    emacinfo     REC   # Info files for emacs-19.34
e    emacmisc     REC   # Miscellaneous files for emacs 19.34.
e    emacsbin     ADD   # GNU Emacs 19.34

f    *            SKP
f    howto1       ADD   # HOWTOs from the Linux Documentation Project (part one).
f    howto2       ADD   # HOWTOs from the Linux Documentation Project (part two).
f    manyfaqs     ADD   # A collection of frequently asked questions/answers on many subjects.
f    mini         ADD   # Mini-HOWTOs.

k    *            SKP
k    lx2030_1     REC   # Linux kernel source version 2.0.30, part one.
k    lx2030_2     REC   # Linux kernel source version 2.0.30, part two.
k    lx2030_3     REC   # Linux kernel source version 2.0.30, part three.
k    lx2030_4     REC   # Linux kernel source version 2.0.30, part four.
k    lx2030_5     REC   # Linux kernel source version 2.0.30, part five.
k    lx2030_6     REC   # Linux kernel source version 2.0.30, part six.

n    *            SKP
n    apache       OPT   # Apache WWW server v 1.2.0
n    bind         REC   # BIND-4.9.5-P1
n    cnews        OPT   # 20 Feb 1993 Performance Release of C News
n    dip          OPT   # DIP - dialup IP connection handler 3.3.7o
n    elm          OPT   # Menu-driven user mail program. (v. 2.4pl25)
n    inn          OPT   # INN 1.4
n    lynx         OPT   # Lynx 2.6
n    mailx        REC   # BSD mailx 5.5.
n    metamail     REC   # metamail-2.7
n    netpipes     OPT   # netpipes 3.1
n    nn-nntp      OPT   # nn-6.4.18 compiled to use NNTP.
n    nn-spool     OPT   # nn-6.4.18 compiled to use a local news spool.
n    pine         OPT   # Pine version 3.96
n    ppp          OPT   # PPP for Linux, version 2.2.0f
n    procmail     OPT   # The procmail mail processing program. (v3.10 1994/10/31)
n    rdist        OPT   # Remote file distribution program.
n    sendmail     REC   # BSD sendmail 8.8.7.
n    smailcfg     OPT   # Configuration files for sendmail.
n    tcpip        REC   # TCP/IP networking programs and support files.
n    tin          OPT   # The 'tin' news reader. (1.2pl2)
n    trn          OPT   # A threaded news reader for the local news spool. (v. 3.5)
n    trn-nntp     OPT   # A threaded news reader for reading a remote NNTP server. (v. 3.5)
n    uucp         OPT   # Taylor UUCP version 1.06.1

t    *            SKP
t    tb-trans     OPT   # transfig 3.1.2.
t    tb-xfig      OPT   # xfig 3.1.4.
t    td-bibt      OPT   # BibTeX documentation.
t    td-eplai     OPT   # eplain documentation.
t    td-fonts     OPT   # fonts documentation.
t    td-gnric     OPT   # generic documentation.
t    td-ltex1     OPT   # LaTeX documentation, part one.
t    td-ltex2     OPT   # LaTeX documentation, part two.
t    td-metap     OPT   # MetaPost documentation.
t    td-misc      OPT   # general TeX documentation.
t    td-mkidx     OPT   # makeindex documentation.
t    td-progs     OPT   # Kpathsea documentation.
t    te-ams       REC   # AMSTeX.
t    te-base1     ADD   # teTeX base package, part one.
t    te-base2     ADD   # teTeX base package, part two.
t    te-bin1      ADD   # teTeX binaries for Intel x86/Linux ELF (part one).
t    te-bin2      ADD   # teTeX binaries for Intel x86/Linux ELF (part two).
t    tf-dc        ADD   # DC fonts.
t    tf-misc      ADD   # miscellaneous fonts.
t    tf-ps        REC   # PostScript fonts.
t    tf-sautr     ADD   # sauter fonts.
t    tm-bibt      REC   # BibTeX.
t    tm-eplai     REC   # expanded plain TeX.
t    tm-lt        ADD   # LaTeX base.
t    tm-lxtra     REC   # LaTeX extra.
t    tm-metap     OPT   # MetaPost.
t    tm-pictx     OPT   # PiCTeX.
t    tm-pstr      OPT   # PS Tricks.
t    tm-tdraw     REC   # TeXdraw macros.
t    tm-xypic     OPT   # XY-pic macros.

tcl  *            SKP
tcl  tcl          ADD   # The Tcl script language, version 7.5
tcl  tclx         REC   # Extended Tcl (TclX) 7.5.0.
tcl  tk           REC   # The Tk toolkit for Tcl, version 4.1
tcl  tkdesk       OPT   # TkDesk 1.0b4

x    *            SKP
x    fvwm         ADD   # FVWM 1.23b
x    fvwmicns     OPT   # Color icons from xpm3icons.tar.Z, found in the /pub/X11/contrib
x    oldlibs5     OPT   # Shared X libraries from XFree86 2.1.1 (X11R5).
x    oldlibs6     OPT   # a.out (DLL) format shared libraries for X11R6 binaries.
x    x338514      REC   # An accelerated server for cards using IBM8514 chips.
x    x33agx       REC   # An accelerated server for IIT AGX-016, AGX-015, and AGX-014 chipsets.
x    x33bin       ADD   # Basic client binaries required for XFree86 3.3.
x    x33cfg       ADD   # Configuration files for XFree86 3.3.
x    x33doc       REC   # Documentation and release notes for XFree86 3.3.
x    x33f100      OPT   # 100-dpi screen fonts.
x    x33fcyr      OPT   # Cyrillic fonts for XFree86 3.3.
x    x33fnon1     OPT   # Large fonts, part one.
x    x33fnon2     OPT   # Large fonts, part two.
x    x33fnts      ADD   # Fonts for the X window system.
x    x33fscl      OPT   # Scaled fonts.
x    x33fsrv      OPT   # xfs (X font server)
x    x33html      OPT   # Docs for XFree86 in HTML format.
x    x33i128      REC   # A server for the Number Nine Imagine 128.
x    x33jdoc      OPT   # Japanese documentation and release notes for XFree86 3.3.
x    x33lib       ADD   # Dynamic libraries and configuration files for XFree86 3.3.
x    x33ma32      REC   # An accelerated server for cards using Mach32 chips.
x    x33ma64      REC   # An accelerated server for cards using the Mach64 chipset.
x    x33ma8       REC   # An accelerated server for cards using Mach8 chips.
x    x33man       REC   # Man pages for XFree86 3.3.
x    x33mono      REC   # A Monochrome server.
x    x33nest      OPT   # Xnest - a nested X server.
x    x33p9k       REC   # An accelerated server for cards using the P9000 chipset.
x    x33prog      REC   # Include files and configuration files for X programming.
x    x33prt       OPT   # Print-only server (Xprt) for XFree86 3.3.
x    x33ps        OPT   # XFree86 documentation in PostScript format.
x    x33s3        REC   # An accelerated server for cards using S3 chips.
x    x33s3v       REC   # An accelerated server for cards using S3 ViRGE chips.
x    x33setup     OPT   # Graphical configuration utility for XFree86.
x    x33svga      REC   # A server for SuperVGA video cards.
x    x33vfb       OPT   # Virtual framebuffer X server.
x    x33vg16      REC   # A server for 16 color EGA/VGA graphics modes.
x    x33w32       REC   # A server for chipsets in the ET4000/W32 series.
x    xlock        ADD   # xlockmore-4.02.1
x    xpm          ADD   # The Xpm shared and static libraries, v. 3.4c (with libXpm.so.4.3)

xap  *            SKP
xap  arena        OPT   # Arena beta-2b
xap  fvwm95       OPT   # fvwm95-2.0.41f
xap  gchess       OPT   # GNU chess (v. 4.0 patch level 77)
xap  ghstview     OPT   # Ghostview 1.5
xap  gnuplot      OPT   # gnuplot 3.5
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  libgr        REC   # libgr-2.0.12
xap  seyon        OPT   # Seyon 2.14c.
xap  x3270        OPT   # x3270 3.1.0.5 - IBM host access tool.
xap  xfileman     OPT   # xfilemanager 0.5
xap  xfm          OPT   # xfm 1.3.2, a file manager for X.
xap  xfract       OPT   # xfractint-3.02
xap  xgames       OPT   # A collection of games for X:
xap  xpaint       OPT   # XPaint 2.4.9.
xap  xspread      OPT   # A spreadsheet for the X window system, version 2.1.
xap  xv           OPT   # John Bradley's XV 3.10a GIF/TIFF/JPEG/PostScript image viewer.
xap  xxgdb        OPT   # xxgdb-1.12.

xd   *            SKP
xd   x33lkit1     OPT   # XFree86 3.3 server linkkit, part one.
xd   x33lkit2     OPT   # XFree86 3.3 server linkkit, part two.
xd   x33lkit3     OPT   # XFree86 3.3 server linkkit, part three.
xd   x33stat      OPT   # Static libraries and configuration files for XFree86 3.3.

xv   *            SKP
xv   sspkg        OPT   # SlingShot extensions 2.1
xv   workman      OPT   # WorkMan-1.2.2a
xv   xv32_a       OPT   # Static libraries for xview3.2p1-X11R6.LinuxELF.2
xv   xv32_so      ADD   # ELF shared libraries for xview3.2p1-X11R6.LinuxELF.2
xv   xv32exmp     OPT   # Sample code for XView
xv   xvinc32      OPT   # Include files for xview3.2p1-X11R6.LinuxELF.2
xv   xvmenus      ADD   # Menus and help files for the OpenLook Window Manager.
xv   xvol32       ADD   # Binaries for xview3.2p1-X11R6.LinuxELF.2

y    *            SKP
y    bsdgames     OPT   # Curtis Olson and Andy Tefft's port of the BSD games collection. (1.3)
y    lizards      OPT   # Lizards -- a video game for Linux.
y    sastroid     OPT   # Sasteroids 1.3
