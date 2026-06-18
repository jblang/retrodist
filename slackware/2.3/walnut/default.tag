a    *            SKP
a    base         ADD   # Basic Linux filesystem package.
a    bash         ADD   # GNU bash-1.14.4
a    bin          ADD   # Binaries that go in /bin and /usr/bin.
a    comms        REC   # Serial file-transfer and communication packages.
a    cpio         ADD   # The GNU cpio backup and archiving utility v. 2.3
a    devs         ADD   # Device files.
a    e2fsbn       ADD   # Utilities for the second extended file system v. 0.5b
a    etc          ADD   # System configuration files that go into the /etc directory.
a    find         ADD   # GNU findutils-4.1
a    getty        OPT   # getty_ps 2.0.7e
a    gpm          REC   # General purpose mouse support v0.98
a    grep         ADD   # GNU grep 2.0
a    gzip         ADD   # GNU zip compression utilities. (v. 1.2.4)
a    hdsetup      ADD   # The Slackware setup/package maintenance system v. 2.3.0
a    idenet       REC   # Linux kernel version 1.2.8, without SCSI support.
a    keytbls      OPT   # kbd 0.90
a    ldso         ADD   # ld.so 1.6.5, the dynamic linker/loader.
a    less         ADD   # less-290
a    lilo         ADD   # LILO 0.16
a    loadlin      REC   # LOADLIN v1.5
a    lpr          ADD   # BSD print spooling system.
a    passwd       ADD
a    ps           ADD   # procps 0.97
a    scsi         REC   # Linux kernel version 1.2.8, with SCSI + IDE support.
a    sh_utils     ADD   # GNU sh-utils-1.12
a    shlibs       ADD   # The shared C libraries libc.so.4.6.27 and libm.so.4.6.27.
a    syslogd      ADD   # Sysklogd 1.2
a    sysvinit     ADD   # SysV style init v. 2.4
a    tar          ADD   # GNU tar 1.11.2
a    tcsh         OPT   # tcsh 6.04
a    txtutils     ADD   # GNU textutils-1.9
a    umsprogs     ADD   # umsdos_progs 0.7
a    util         ADD   # util-linux 2.2
a    zoneinfo     ADD   # Time zone utilities

ap   *            SKP
ap   ash          OPT   # Kenneth Almquist's ash shell.
ap   bc           OPT   # GNU bc 1.03 - An arbitrary precision calculator language.
ap   diff         REC   # GNU diffutils-2.7
ap   ftape        OPT   # ftape 2.02e
ap   ghostscr     OPT   # Ghostscript version 2.6.2
ap   gp9600       OPT   # Change the default modem speed from 9600 baud.
ap   groff        REC   # GNU troff 1.09 document formatting system.
ap   gsfonts1     OPT   # Fonts for the Ghostscript interpreter/previewer.
ap   gsfonts2     OPT   # More fonts for the Ghostscript interpreter/previewer.
ap   ispell       OPT   # ispell-3.1.08
ap   jed          OPT   # John E. Davis's JED 0.96 editor.
ap   joe          OPT   # Joe text editor, 2.2.
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.14.10)
ap   jpeg         OPT   # Independent JPEG Group's 5beta2 JPEG software
ap   man          REC   # On-line manual pages.
ap   manpgs       REC   # Man-pages 1.4
ap   mt           OPT
ap   mt_st        OPT   # mt-st-0.2 - controls magnetic tape drive operation
ap   quota        OPT   # Disk quota utilities.
ap   sc           OPT   # The 'sc' spreadsheet. (v. 6.21)
ap   shlbsvga     REC   # Shared library libsvga.so.1.2.6 (from svgalib126)
ap   sudo         OPT   # sudo 1.2
ap   termbin      OPT   # Term 2.3.5
ap   termnet      OPT   # Network utilities for term
ap   termsrc      OPT   # Term 2.3.5 source code
ap   texinfo      REC   # GNU texinfo-3.1
ap   vim          OPT   # Version 3.0 of Vim: Vi IMproved
ap   workbone     OPT   # Workbone 2.3
ap   zsh          OPT   # zsh version 2.4

d    *            SKP
d    binutils     ADD   # GNU binutils 2.5.2(.6)
d    bison        REC   # GNU bison parser generator version 1.22.
d    byacc        REC   # Berkeley Yacc is an LALR(1) parser generator.  Berkeley Yacc
d    clisp        OPT   # A Common Lisp interpreter. (CLISP version 4-Jul-94)
d    extralib     OPT   # Extra static libraries used for profiling and debugging. (v. 4.6.27)
d    f2c          OPT   # A Fortran-77 to C translator.
d    flex         ADD   # flex - fast lexical analyzer generator version 2.5.2
d    gcc          REC
d    gdb          REC   # The GNU debugger. (v. 4.14)
d    gmake        ADD   # GNU make utility 3.73.
d    gxx          REC
d    include      ADD   # Standard include files needed to compile C programs.  (v. 4.6.27)
d    libc         ADD   # Development libraries for the C compiler. (v. 4.6.27)
d    libgxx       REC   # GNU libg++-2.6.2, Linux release 1
d    lx128_1      REC   # Linux kernel source version 1.2.8, part one.
d    lx128_2      REC   # Linux kernel source version 1.2.8, part two. (include files)
d    lx128_3      REC   # Linux kernel source version 1.2.8, part three.
d    m4           REC   # GNU m4 1.4
d    man2         REC   # Man pages for Linux system calls. (from manpages-1.4)
d    man3         REC   # Man pages for the C library functions. (from manpages-1.4)
d    ncurses      REC   # A curses-compatible screen management library with color. (v. 1.8.6)
d    objc         OPT
d    p2c          OPT   # A Pascal to C translator. (v. 1.19)
d    perl         OPT   # Larry Wall's interpreted systems language. (v. 4.0pl36)
d    pmake        ADD   # BSD 4.4 make. This may be required if you're going to port software
d    rcs          OPT   # GNU revision control system.  (v. 5.6.0.1)
d    strace       OPT   # strace 3.0 - traces system calls and signals.
d    svgalib      OPT   # Svgalib Super-VGA Graphics Library (v126)
d    tools        OPT   # tools 2.17

e    *            SKP
e    elisp1       OPT   # Part one of the Lisp source files for Emacs 19.28.
e    elisp2       OPT   # Part two of the Lisp source files for Emacs 19.28.
e    elispc       REC   # These are compiled lisp files for GNU Emacs 19.28.
e    emac_nox     OPT   # A replacement /usr/bin/emacs-19.28 binary that is not compiled with
e    emacmisc     REC   # Miscellaneous files for emacs 19.28.
e    emacsbin     ADD   # GNU Emacs 19.28

f    *            SKP
f    howto        ADD   # The collection of HOWTOs from the Linux Documentation Project.
f    manyfaqs     ADD   # A collection of frequently asked questions/answers on many subjects.

i    *            SKP
i    info1        ADD   # Part one of the info files collection.
i    info2        ADD   # Part two of the info files collection.
i    info3        ADD   # Part three of the info files collection.

iv   *            SKP
iv   iv_31        ADD   # Binaries, libraries, and miscellaneous files for InterViews 3.1
iv   iv_docs      ADD   # Documentation files for InterViews 3.1.
iv   iv_inc       ADD   # InterViews 3.1 include files.

n    *            SKP
n    bind         REC   # BIND-4.9.3-beta9
n    cnews        OPT   # 20 Feb 1993 Performance Release of C News
n    deliver      OPT   # A small and simple program that delivers electronic mail once it
n    dip          OPT   # DIP - dialup IP connection handler 3.3.7n
n    elm          OPT   # Menu-driven user mail program. (v. 2.4pl23)
n    inn          OPT   # INN 1.4
n    lynx         OPT
n    mailx        REC   # BSD mailx 5.5.
n    netcfg       REC   # 'netconfig' is a script to help configure TCP/IP and mail on your
n    nn-nntp      OPT   # nn-6.4.18 compiled to use NNTP.
n    nn-spool     OPT   # nn-6.4.18 compiled to use a local news spool.
n    pine         OPT   # Pine version 3.91
n    ppp          OPT   # PPP for Linux, version 2.1.2b
n    rdist        OPT   # Remote file distribution program.
n    sendmail     REC   # BSD sendmail 8.6.12.
n    smailcfg     OPT   # Configuration files for sendmail.
n    tcpip        REC   # TCP/IP networking programs and support files.
n    tin          OPT   # The 'tin' news reader. (1.2pl2)
n    trn          OPT   # A threaded news reader for the local news spool. (v. 3.5)
n    trn-nntp     OPT   # A threaded news reader for reading a remote NNTP server. (v. 3.5)
n    uucp         OPT   # Taylor UUCP version 1.05

oop  *            SKP
oop  smaltalk     ADD   # GNU Smalltalk 1.1.1
oop  stix         ADD   # A Smalltalk interface to X11.

q    *            SKP
q    aztech1      OPT   # Linux kernel 1.2.8 with Aztech/Orchid/Wearnes CD-ROM drivers.
q    aztech2      OPT   # Linux kernel 1.2.8 with Aztech/Orchid/Wearnes CD-ROM drivers.
q    bare         OPT   # Linux kernel 1.2.8 with IDE hard drive support.
q    cdu31a1      OPT   # Linux kernel version 1.2.8, with Sony CDU31A/CDU33A driver.
q    cdu31a2      OPT   # Linux kernel version 1.2.8, with Sony CDU31A/CDU33A driver.
q    cdu535_1     OPT   # Linux kernel version 1.2.8, with Sony 531/535 driver.
q    cdu535_2     OPT   # Linux kernel version 1.2.8, with Sony 531/535 driver.
q    idecd1       OPT   # Linux kernel version 1.2.8, with IDE/ATAPI CD-ROM support.
q    idecd2       OPT   # Linux kernel version 1.2.8, with IDE/ATAPI CD-ROM support.
q    idenet       OPT   # Linux kernel version 1.2.8, with IDE and network drivers.
q    mitsumi1     OPT   # Linux kernel version 1.2.8, with SCSI+IDE+Mitsumi CD support.
q    mitsumi2     OPT   # Linux kernel version 1.2.8, with SCSI+IDE+Mitsumi CD support.
q    old31a       OPT   # Linux kernel version 1.1.59 with Sony CDU31a/33a CD-ROM support.
q    sbpcd1       OPT   # Linux kernel version 1.2.8, with SCSI+IDE+Soundblaster CD support.
q    sbpcd2       OPT   # Linux kernel version 1.2.8, with SCSI+IDE+Soundblaster CD support.
q    scsi         OPT   # Linux kernel version 1.2.8, with SCSI + IDE support.
q    scsinet1     OPT   # Linux kernel version 1.2.8, with SCSI + IDE support.
q    scsinet2     OPT   # Linux kernel version 1.2.8, with SCSI + IDE support.
q    xt           OPT   # Linux kernel version 1.2.8, with IDE+XT (MFM/RLL) drive support.

t    *            SKP
t    gentle       REC   # A Gentle Introduction to TeX
t    ntb-b2d      OPT   # ntb-b2d 1.0
t    ntb-bibt     REC   # ntb-bibt 1.1
t    ntb-djc      OPT   # ntb-djc 0.1
t    ntb-dlj      REC   # ntb-dlj 1.2
t    ntb-dps      REC   # ntb-dps 1.2
t    ntb-gsfp     REC   # ntb-gsfp 1.0
t    ntb-html     OPT   # ntb-html 1.1
t    ntb-indx     REC   # ntb-indx 1.1
t    ntb-kpat     OPT   # ntb-kpat 1.1
t    ntb-mf       ADD   # ntb-mf 1.2
t    ntb-tex      ADD   # ntb-tex 1.2
t    ntb-traf     OPT   # ntb-traf 1.1
t    ntb-utl1     REC   # ntb-utl1 1.1
t    ntb-utl2     ADD   # ntb-utl2 1.1
t    ntb-utl3     REC   # ntb-utl3 1.1
t    ntb-xdvi     REC   # ntb-xdvi 1.2
t    ntb-xfig     REC   # ntb-xfig 1.1
t    ntf-ams      REC   # ntf-ams 1.2
t    ntf-astr     OPT   # ntf-astr 1.1
t    ntf-bard     OPT   # ntf-bard 1.1
t    ntf-bbm      OPT   # ntf-bbm 1.2
t    ntf-bl       OPT   # ntf-bl 1.1
t    ntf-call     OPT   # ntf-call 1.2
t    ntf-cher     OPT   # ntf-cher 1.2
t    ntf-cmas     OPT   # ntf-cmas 1.1
t    ntf-cmb      OPT   # ntf-cmb 1.2
t    ntf-cmca     OPT   # ntf-cmca 1.2
t    ntf-cmcy     OPT   # ntf-cmcy 1.2
t    ntf-cml      ADD   # ntf-cml 1.2
t    ntf-cmoe     OPT   # ntf-cmoe 1.1
t    ntf-cmpc     OPT   # ntf-cmpc 1.1
t    ntf-cms      ADD   # ntf-cms 1.2
t    ntf-cmts     OPT   # ntf-cmts 1.1
t    ntf-cmu      REC   # ntf-cmu 1.1
t    ntf-conc     OPT   # ntf-conc 1.1
t    ntf-cypr     OPT   # ntf-cypr 1.2
t    ntf-dc       REC   # ntf-dc 1.1
t    ntf-ding     OPT   # ntf-ding 1.1
t    ntf-duer     OPT   # ntf-duer 1.1
t    ntf-elvi     OPT   # ntf-elvi 1.1
t    ntf-engw     OPT   # ntf-engw 1.2
t    ntf-fc       OPT   # ntf-fc 1.1
t    ntf-futh     OPT   # ntf-futh 1.1
t    ntf-geor     OPT   # ntf-geor 1.1
t    ntf-go       OPT   # ntf-go 1.1
t    ntf-goth     OPT   # ntf-goth 1.1
t    ntf-hand     OPT   # ntf-hand 1.1
t    ntf-hge      OPT   # ntf-hge 1.1
t    ntf-kart     OPT   # ntf-kart 1.2
t    ntf-klin     OPT   # ntf-klin 1.2
t    ntf-la       OPT   # ntf-la 1.2
t    ntf-logi     OPT   # ntf-logi 1.2
t    ntf-logo     OPT   # ntf-logo 1.1
t    ntf-ocm      OPT   # ntf-ocm 1.1
t    ntf-ocra     OPT   # ntf-ocra 1.1
t    ntf-ogha     OPT   # ntf-ogha 1.1
t    ntf-okud     OPT   # ntf-okud 1.1
t    ntf-osma     OPT   # ntf-osma 1.1
t    ntf-pand     OPT   # ntf-pand 1.1
t    ntf-phon     OPT   # ntf-phon 1.1
t    ntf-ps       OPT   # ntf-ps 1.2
t    ntf-punk     OPT   # ntf-punk 1.1
t    ntf-recy     OPT   # ntf-recy 1.1
t    ntf-rsfs     OPT   # ntf-rsfs 1.1
t    ntf-rune     OPT   # ntf-rune 1.1
t    ntf-stma     OPT   # ntf-stma 1.1
t    ntf-teng     OPT   # ntf-teng 1.1
t    ntf-thai     OPT   # ntf-thai 1.2
t    ntf-twca     OPT   # ntf-twca 1.1
t    ntf-ugar     OPT   # ntf-ugar 1.0
t    ntf-wasy     OPT   # ntf-wasy 1.1
t    ntf-wsui     OPT   # ntf-wsui 1.1
t    ntf-xcmr     OPT   # ntf-xcmr 1.1
t    ntm-amst     REC   # ntm-amst 1.1
t    ntm-arab     OPT   # ntm-arab 1.2
t    ntm-deva     OPT   # ntm-deva 1.1
t    ntm-etex     REC   # ntm-etex 1.2
t    ntm-germ     OPT   # ntm-germ 1.0
t    ntm-gree     OPT   # ntm-gree 1.2
t    ntm-hebr     OPT   # ntm-hebr 1.2
t    ntm-hier     OPT   # ntm-hier 1.2
t    ntm-ltx1     ADD   # ntm-ltx1 1.2
t    ntm-ltx2     REC   # ntm-ltx2 1.2
t    ntm-ltx3     REC   # ntm-ltx3 1.2
t    ntm-ltx4     REC   # ntm-ltx4 1.1
t    ntm-pict     OPT   # ntm-pict 1.0
t    ntm-plft     OPT   # ntm-plft 1.1
t    ntm-tami     OPT   # ntm-tami 1.1
t    ntm-tex      ADD   # ntm-tex 1.1
t    ntm-turk     OPT   # ntm-turk 1.1
t    ntm-viet     OPT   # ntm-viet 1.1

tcl  *            SKP
tcl  blt          OPT   # This is the version 1.7 release of the blt library.  It is an
tcl  itcl         OPT   # [incr Tcl] - version 1.5
tcl  tcl          ADD   # The Tcl script language, version 7.3
tcl  tclx         OPT   # TclX - Extended Tcl: Extended command set for Tcl (v. 7.3b)
tcl  tk           REC   # The Tk toolkit for Tcl, version 3.6

x    *            SKP
x    fnt100_1     OPT   # 100-dpi screen fonts (part one)
x    fnt100_2     OPT   # 100-dpi screen fonts (part two)
x    fntbig1      OPT   # Large fonts (part one)
x    fntbig2      OPT   # Large fonts (part two)
x    fntbig3      OPT   # Large fonts (part three)
x    fvwmicns     OPT   # Color icons from xpm3icons.tar.Z, found in the /pub/X11/contrib
x    oldlibs      REC   # Shared X libraries from XFree86 2.1.1 (X11R5).
x    x3118514     REC   # An accelerated server for cards using IBM8514 chips.
x    x311agx      REC   # An accelerated server for IIT AGX-016, AGX-015, and AGX-014 chipsets.
x    x311bin      ADD   # Basic client binaries required for XFree86 3.1.1.
x    x311cfg      ADD   # Configuration files for XFree86 3.1.1.
x    x311ctrb     OPT   # Selected contrib programs for X11R6:
x    x311doc      OPT   # Documentation and release notes for XFree86 3.1.1.
x    x311f75      REC   # 75dpi Fonts for the X window system.
x    x311fnt      ADD   # Fonts for the X window system.
x    x311fscl     OPT   # Scaled fonts.
x    x311inc      REC   # Header files for X11 programming.
x    x311lib      ADD   # Dynamic libraries and configuration files for XFree86 3.1.1.
x    x311ma32     REC   # An accelerated server for cards using Mach32 chips.
x    x311ma64     REC   # An accelerated server for cards using the Mach64 chipset.
x    x311ma8      REC   # An accelerated server for cards using Mach8 chips.
x    x311man      REC   # Man pages for programs that come with XFree86 3.1.1.
x    x311mono     REC   # A Monochrome server.
x    x311p9k      REC   # An accelerated server for cards using the P9000 chipset.
x    x311s3       REC   # An accelerated server for cards using S3 chips.
x    x311svga     REC   # A server for SuperVGA video cards.
x    x311ubin     OPT   # Rstartd daemon.
x    x311vga      REC   # A server for 16 color EGA/VGA graphics modes.
x    x311w32      REC   # A server for chipsets in the ET4000/W32 series.
x    x311xtra     OPT   # Two optional experimental servers for X11R6.
x    xlock        ADD   # xlockmore-2.7
x    xpm          ADD   # The Xpm shared and static libraries, v. 3.4c (with libXpm.so.4.3)

xap  *            SKP
xap  gchess       OPT   # GNU chess (v. 4.00 patch level 69)
xap  ghstview     OPT   # Ghostview 1.5
xap  gnuplot      OPT   # gnuplot 3.5
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  libgr        REC   # libgr-1.3
xap  seyon        OPT   # Seyon 2.14c.
xap  vgaset       REC   # Utility to help you configure your monitor for X more easily.
xap  x3270        OPT   # x3270 3.0.1.3 - IBM host access tool.
xap  xfileman     OPT   # xfilemanager 0.5
xap  xfm          OPT   # xfm 1.3, a file manager for X.
xap  xfract       OPT   # xfractint-2.03
xap  xgames       OPT   # A collection of games for X:
xap  xpaint       OPT   # XPaint 2.1
xap  xspread      OPT   # A spreadsheet for the X window system, version 2.1.
xap  xv           OPT   # John Bradley's XV 3.10 GIF/TIFF/JPEG/PostScript image viewer.
xap  xxgdb        OPT   # xxgdb-1.08.

xd   *            SKP
xd   x311pex      OPT   # XFree86 3.1.1 PEX distribution
xd   x311slib     OPT   # Static versions of the X libraries.
xd   xd_lkit1     OPT   # XFree86 3.1.1 Linkkit (part one)
xd   xd_lkit2     OPT   # XFree86 3.1.1 Linkkit (part two)

xv   *            SKP
xv   workman      OPT   # WorkMan-1.2.2a
xv   xv32_a       OPT   # Static libraries for xview3.2p1-X11R6.
xv   xv32_sa      OPT   # Shared library stubs for xview3.2p1-X11R6.
xv   xv32_so      ADD   # DLL (shared) libraries for xview3.2p1-X11R6.
xv   xv32exmp     OPT   # Sample programs for Xview which demonstrate the Slingshot and UIT
xv   xvinc32      OPT   # Include files for xview3.2p1-X11R6.
xv   xvmenus      ADD   # Menus and help files for the OpenLook Window Manager.
xv   xvol32       ADD   # Binaries for xview3.2p1-X11R6.

y    *            SKP
y    bsdgames     OPT   # Curtis Olson and Andy Tefft's port of the BSD games collection. (1.3)
y    doom         OPT   # Doom 1.8 for Linux
y    doomwad      OPT   # Part one of the wadfile for DOOM.
y    doomwad2     OPT   # Part two of the wadfile for DOOM.
y    sastroid     OPT   # Sasteroids 1.3
y    tetris       OPT   # Tetris for terminals.
