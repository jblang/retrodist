a    *            SKP
a    aaa_base     ADD   # Basic Linux filesystem package.
a    aoutlibs     ADD   # a.out shared libraries:
a    bash         ADD   # GNU bash-1.14.7
a    bin          ADD   # Binaries that go in /bin and /usr/bin.
a    bsdlpr       REC   # BSD lpr-5.9-26
a    bzip2        ADD   # bzip2 version 0.9.0b (a block-sorting file compressor)
a    cpio         ADD   # The GNU cpio backup and archiving utility v. 2.4.2
a    devs         ADD   # Device files.
a    e2fsbn       ADD   # Utilities for the second extended file system v. 1.12
a    elflibs      ADD   # ELF shared libraries.
a    etc          ADD   # System configuration files that go into the /etc directory.
a    fileutls     ADD   # fileutils-3.16
a    find         ADD   # GNU findutils-4.1
a    getty        OPT   # getty_ps 2.0.7j
a    glibc1       ADD   # glibc-2.0.7pre6 runtime support
a    glibc2       ADD   # glibc-2.0.7pre6 internationalization files
a    gpm          REC   # General purpose mouse support v1.14
a    grep         ADD   # GNU grep 2.1
a    gzip         ADD   # GNU zip compression utilities. (v. 1.2.4)
a    hdsetup      ADD   # The Slackware setup/package maintenance system v. 3.6.0
a    ibcs2        OPT   # Intel Binary Compatibility Specification module
a    ide          REC   # Linux kernel version 2.0.35, without SCSI support.
a    joystick     OPT   # joystick-0.8.0.
a    kbd          REC   # kbd 0.95
a    ldso         ADD   # ld.so 1.9.9, the dynamic linker/loader.
a    less         ADD   # less-332
a    lilo         ADD   # LILO 20
a    loadlin      REC   # LOADLIN v1.6a
a    minicom      REC   # Minicom 1.81.1
a    modules      ADD   # Linux kernel modules for 2.0.35.
a    modutils     ADD   # modutils-2.1.121
a    pcmcia       REC   # pcmcia-cs-3.0.5
a    pnp          OPT   # isapnptools-1.15
a    procps       ADD   # procps-1.2.9
a    scsi         REC   # Linux kernel version 2.0.35, with SCSI support.
a    scsimods     ADD   # Linux SCSI kernel modules for 2.0.35.
a    sh_utils     ADD   # GNU sh-utils-1.16
a    shadow       ADD   # Shadow password suite (shadow-980724)
a    sysklogd     ADD   # Sysklogd 1.3-25
a    sysvinit     ADD   # SysVinit v. 2.73
a    tar          ADD   # GNU tar 1.12
a    tcsh         REC   # tcsh 6.07
a    txtutils     ADD   # GNU textutils-1.22
a    umsprogs     ADD   # umsdos_progs 0.9
a    util         ADD   # util-linux 2.7.1 - A huge collection of essential utilities.
a    zoneinfo     ADD   # Time zone utilities and database.

ap   *            SKP
ap   ash          OPT   # Kenneth Almquist's ash shell.
ap   bc           OPT   # GNU bc 1.04 - An arbitrary precision calculator language.
ap   cdutils      OPT   # Tools for mastering and writing compact discs.
ap   diff         REC   # GNU diffutils-2.7
ap   ghostscr     REC   # Ghostscript version 4.03
ap   groff        ADD   # GNU troff 1.11 document formatting system.
ap   gsfonts      REC   # Fonts for the Ghostscript interpreter/previewer.
ap   ispell       OPT   # ispell-3.1.20
ap   jed          OPT   # John E. Davis's JED 0.97-14 editor.
ap   joe          OPT   # Joe text editor v2.8
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.14.10)
ap   jpeg6        OPT   # Independent JPEG Group's JPEG software version 6b
ap   manpages     REC   # Man-pages 1.21
ap   mc           OPT   # Midnight Commander version 4.1.35
ap   md           OPT   # md-0.35 (multiple device utilities)
ap   mt_st        OPT   # mt-st-0.4 - controls magnetic tape drive operation
ap   quota        OPT   # Linux disk quota utilities (1.70)
ap   sc           OPT   # The 'sc' spreadsheet. (v. 6.21)
ap   seejpeg      REC   # seejpeg-1.6.1
ap   sox          REC   # sox-11gamma-cb3
ap   sudo         OPT   # sudo-1.5.4
ap   texinfo      REC   # GNU texinfo-3.12
ap   vim          OPT   # Version 5.1 of Vim: Vi IMproved
ap   workbone     OPT   # Workbone 2.31
ap   zsh          OPT   # zsh version 3.0.3

d    *            SKP
d    binutils     ADD   # GNU binutils 2.8.1.0.23
d    bison        ADD   # GNU bison parser generator version 1.25.
d    byacc        OPT   # Berkeley Yacc is an LALR(1) parser generator.  Berkeley Yacc
d    egcs         ADD   # The GNU C and C++ compilers (egcs-1.0.3).
d    egcs_g77     OPT   # GNU Fortran-77 compiler from the egcs-1.0.3 release.
d    egcsobjc     OPT   # GNU Objective-C compiler from the egcs-1.0.3 release.
d    flex         ADD   # flex - fast lexical analyzer generator version 2.5.4
d    gcc          OPT   # The GNU C compiler and support files (v. 2.7.2.3)
d    gcl          OPT   # GNU Common LISP 2.2.2
d    gdb          OPT   # The GNU debugger. (v. 4.17)
d    gmake        ADD   # GNU make utility 3.76.1.
d    libc         ADD   # Development libraries for the C compiler.
d    libcinfo     OPT   # C library documentation
d    linuxinc     ADD   # Linux 2.0.35 kernel include files
d    m4           REC   # GNU m4 1.4
d    ncurses      REC   # A curses-compatible screen management library with color. (v. 1.9.9g)
d    p2c          OPT   # A Pascal to C translator. (v. 1.19)
d    perl         REC   # Larry Wall's interpreted systems language. (v. 5.005_02)
d    pmake        REC   # BSD 4.4 make.
d    python       OPT   # python-1.5.1.
d    rcs          OPT   # GNU revision control system.  (v. 5.7)
d    strace       OPT   # strace-3.1.0.1 - traces system calls and signals.
d    svgalib      OPT   # Svgalib Super-VGA Graphics Library 1.3.0
d    terminfo     OPT   # Complete /usr/share/terminfo database.

e    *            SKP
e    elisp        OPT   # Emacs lisp source files.
e    emac_nox     OPT   # Emacs binary without X support.
e    emacinfo     REC   # Info files for emacs-20.3
e    emacmisc     REC   # Miscellaneous files for emacs-20.3.
e    emacsbin     ADD   # GNU Emacs 20.3

f    *            SKP
f    howto        ADD   # HOWTOs from the Linux Documentation Project.
f    manyfaqs     ADD   # A collection of frequently asked questions/answers on many subjects.
f    mini         ADD   # Linux Mini-HOWTOs.

k    *            SKP
k    linuxinc     REC   # Linux 2.0.35 kernel include files.
k    lx2035       REC   # Linux kernel source version 2.0.35.

n    *            SKP
n    apache       OPT   # Apache WWW server v 1.3.3
n    bind         REC   # BIND-8.1.2-REL.
n    cnews        OPT   # 20 Feb 1993 Performance Release of C News
n    dip          OPT   # DIP - dialup IP connection handler 3.3.7o
n    elm          OPT   # Menu-driven user mail program. (v. 2.4pl25)
n    imapd        OPT   # ipop3d/imapd from Pine 4.05
n    inn          OPT   # INN-1.7.2
n    lynx         OPT   # Lynx 2.8
n    mailx        REC   # BSD mailx 8.1.1.
n    metamail     REC   # metamail-2.7
n    netatalk     OPT   # netatalk-1.4b2
n    netmods      ADD   # Network support modules for linux-2.0.35.
n    netpipes     OPT   # netpipes 3.1
n    nn_nntp      OPT   # nn-6.5.0.b3 compiled to use NNTP.
n    pine         OPT   # Pine version 4.05
n    ppp          OPT   # PPP for Linux, versions 2.2.0f and 2.3.5
n    procmail     OPT   # The procmail mail processing program. (v3.11pre7 1997/04/28)
n    rdist        OPT   # rdist-6.1.3.
n    samba        OPT   # Samba 1.9.18p10
n    sendmail     REC   # BSD sendmail 8.9.1.
n    smailcfg     OPT   # Configuration files for sendmail.
n    tcpip1       REC   # TCP/IP networking programs and support files.
n    tcpip2       REC   # Extra TCP/IP programs.
n    tin          OPT   # The 'tin' news reader. (pre-1.4 release 980226)
n    trn          OPT   # A threaded news reader for reading a remote NNTP server. (v. 3.5)
n    uucp         OPT   # Taylor UUCP version 1.06.1

t    *            SKP
t    tb_trans     OPT   # transfig 3.1.2.
t    tb_xfig      OPT   # xfig 3.1.4.
t    td_bibt      OPT   # BibTeX documentation.
t    td_eplai     OPT   # eplain documentation.
t    td_fonts     OPT   # fonts documentation.
t    td_gnric     OPT   # generic documentation.
t    td_ltex      OPT   # LaTeX documentation.
t    td_metap     OPT   # MetaPost documentation.
t    td_misc      OPT   # general TeX documentation.
t    td_mkidx     OPT   # makeindex documentation.
t    td_progs     OPT   # Kpathsea documentation.
t    te_ams       REC   # AMSTeX.
t    te_base      ADD   # teTeX base package.
t    te_bin       ADD   # teTeX binaries for Intel x86/Linux ELF.
t    tf_dc        ADD   # DC fonts.
t    tf_misc      ADD   # miscellaneous fonts.
t    tf_ps        REC   # PostScript fonts.
t    tf_sautr     ADD   # sauter fonts.
t    tm_bibt      REC   # BibTeX.
t    tm_eplai     REC   # expanded plain TeX.
t    tm_lt        ADD   # LaTeX base.
t    tm_lxtra     REC   # LaTeX extra.
t    tm_metap     OPT   # MetaPost.
t    tm_pictx     OPT   # PiCTeX.
t    tm_pstr      OPT   # PS Tricks.
t    tm_tdraw     REC   # TeXdraw macros.
t    tm_xypic     OPT   # XY-pic macros.

tcl  *            SKP
tcl  hfsutils     OPT   # hfsutils-3.1.
tcl  tcl          ADD   # The Tcl script language, version 8.0p2.
tcl  tclx         REC   # Extended Tcl (TclX) 8.0.2.
tcl  tk           REC   # The Tk toolkit for Tcl, version 8.0p2.

x    *            SKP
x    fvwm2        ADD   # fvwm2_2.0.46-BETA
x    fvwmicns     OPT   # xpm3icons.
x    lesstif      REC   # LessTif 0.85 (A Motif 1.2 alternative)
x    ltstatic     OPT   # Static libraries for LessTif 0.85
x    oldlibs5     OPT   # Shared X libraries from XFree86 2.1.1 (X11R5).
x    oldlibs6     OPT   # a.out (DLL) format shared libraries for X11R6 binaries.
x    x3328514     REC   # An accelerated server for cards using IBM8514 chips.
x    x332agx      REC   # An accelerated server for IIT AGX chipsets.
x    x332bin      ADD   # Basic client binaries required for XFree86 3.3.2.
x    x332cfg      ADD   # Configuration files for XFree86 3.3.2.
x    x332doc      REC   # Documentation and release notes for XFree86 3.3.2.
x    x332f100     OPT   # 100-dpi screen fonts.
x    x332fcyr     OPT   # Cyrillic fonts for XFree86 3.3.2.
x    x332fnon     OPT   # Some large X fonts.
x    x332fnts     ADD   # Fonts for the X window system.
x    x332fscl     OPT   # Scaled fonts.
x    x332fsrv     OPT   # xfs (X font server)
x    x332html     OPT   # Docs for XFree86 in HTML format.
x    x332i128     REC   # A server for the Number Nine Imagine 128.
x    x332jdoc     OPT   # Japanese documentation and release notes for XFree86 3.3.2.
x    x332jset     OPT   # Japanese configuration utility for XFree86.
x    x332lib      ADD   # Various library files for XFree86 3.3.2.
x    x332ma32     REC   # An accelerated server for cards using Mach32 chips.
x    x332ma64     REC   # An accelerated server for cards using the Mach64 chipset.
x    x332ma8      REC   # An accelerated server for cards using Mach8 chips.
x    x332man      REC   # Man pages for XFree86 3.3.2.
x    x332mono     REC   # A Monochrome server.
x    x332nest     OPT   # Xnest - a nested X server.
x    x332p9k      REC   # An accelerated server for cards using the P9000 chipset.
x    x332prog     REC   # Libraries, include files, and configuration files for X programming.
x    x332prt      OPT   # Print-only server (Xprt) for XFree86 3.3.2.
x    x332ps       OPT   # XFree86 documentation in PostScript format.
x    x332s3       REC   # An accelerated server for cards using S3 chips.
x    x332s3v      REC   # An accelerated server for cards using S3 ViRGE chips.
x    x332set      OPT   # Graphical configuration utility for XFree86.
x    x332svga     REC   # A server for many SuperVGA video cards.
x    x332vfb      OPT   # Virtual framebuffer X server.
x    x332vg16     REC   # A server for 16 color EGA/VGA graphics modes.
x    x332w32      REC   # A server for chipsets in the ET4000/W32 series.
x    xaw3d        ADD   # Xaw3d-1.4
x    xlock        ADD   # xlockmore-4.09
x    xpm          ADD   # The Xpm shared and static libraries, v. 3.4k (with libXpm.so.4.11)

xap  *            SKP
xap  arena        OPT   # Arena beta-3b
xap  freefont     OPT   # freefonts-0.10
xap  fvwm95       OPT   # fvwm95-2.0.43b
xap  gchess       OPT   # GNU chess (v. 4.0 patch level 77)
xap  gimp         OPT   # The GIMP -- GNU Image Manipulation Program version 1.0.2
xap  gnuplot      OPT   # gnuplot 3.5
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  gv           REC   # gv 3.5.8
xap  libgr        REC   # libgr-2.0.13
xap  netscape     REC   # Netscape Communicator 4.07. (v407-export.x86-unknown-linux2.0_libc5)
xap  qt_1_41      OPT   # Qt-1.41
xap  seyon        OPT   # Seyon 2.14c.
xap  tkdesk       REC   # TkDesk 1.0
xap  x3270        OPT   # x3270 3.1.0.5 - IBM host access tool.
xap  xfileman     OPT   # xfilemanager 0.5
xap  xfm          OPT   # xfm 1.3.2, a file manager for X.
xap  xfract       OPT   # xfractint-3.04
xap  xgames       OPT   # A collection of games for X:
xap  xpaint       OPT   # XPaint 2.4.9.
xap  xpdf         OPT   # xpdf-0.7a
xap  xspread      OPT   # xspread-2.1
xap  xv           REC   # John Bradley's XV 3.10a GIF/TIFF/JPEG/PostScript image viewer.
xap  xxgdb        OPT   # xxgdb-1.12.

xd   *            SKP
xd   x332lkit     OPT   # XFree86 3.3.2 server linkkit.

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
y    bsdgames     OPT   # BSD games collection, version 2.0.
y    koules       OPT   # Koules 1.4
y    lizards      OPT   # Lizards -- a video game for Linux.
y    sastroid     OPT   # Sasteroids 1.3
