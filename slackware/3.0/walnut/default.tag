a    *            SKP
a    aaa_base     ADD   # Basic Linux filesystem package.
a    bash         ADD   # GNU bash-1.14.5
a    bin          ADD   # Binaries that go in /bin and /usr/bin.
a    comms        REC   # Serial file-transfer and communication packages.
a    cpio         ADD   # The GNU cpio backup and archiving utility v. 2.3
a    devs         ADD   # Device files.
a    e2fsbn       ADD   # Utilities for the second extended file system v. 0.5b
a    etc          ADD   # System configuration files that go into the /etc directory.
a    find         ADD   # GNU findutils-4.1
a    getty        OPT   # getty_ps 2.0.7e
a    gpm          REC   # General purpose mouse support v1.00
a    grep         ADD   # GNU grep 2.0
a    gzip         ADD   # GNU zip compression utilities. (v. 1.2.4)
a    hdsetup      ADD   # The Slackware setup/package maintenance system v. 3.0.0
a    ibcs2        OPT   # Intel Binary Compatibility Specification module
a    idenet       REC   # Linux kernel version 1.2.13, without SCSI support.
a    keytbls      OPT   # kbd 0.90
a    ldso         ADD   # ld.so 1.7.3, the dynamic linker/loader.
a    less         ADD   # less-290
a    lilo         ADD   # LILO 0.16
a    loadlin      REC   # LOADLIN v1.5
a    lpr          ADD   # BSD print spooling system.
a    pcmcia       OPT   # pcmcia-cs-2.6.3
a    ps           ADD   # procps 0.97
a    scsi         REC   # Linux kernel version 1.2.13, with SCSI + IDE support.
a    sh_utils     ADD   # GNU sh-utils-1.12
a    shlibs       ADD   # ELF shared libraries
a    syslogd      ADD   # Sysklogd 1.2
a    sysvinit     ADD   # SysV style init v. 2.57b
a    tar          ADD   # GNU tar 1.11.2
a    tcsh         OPT   # tcsh 6.04
a    txtutils     ADD   # GNU textutils-1.9
a    umsprogs     ADD   # umsdos_progs 0.7
a    util         ADD   # util-linux 2.4
a    zoneinfo     ADD   # Time zone utilities

ap   *            SKP
ap   ash          OPT   # Kenneth Almquist's ash shell.
ap   bc           OPT   # GNU bc 1.03 - An arbitrary precision calculator language.
ap   diff         REC   # GNU diffutils-2.7
ap   ftape        OPT   # ftape 2.03b
ap   ghostscr     OPT   # Ghostscript version 2.6.2
ap   gp9600       OPT   # Change the default modem speed from 9600 baud.
ap   groff        REC   # GNU troff 1.09 document formatting system.
ap   gsfonts1     OPT   # Fonts for the Ghostscript interpreter/previewer.
ap   gsfonts2     OPT   # More fonts for the Ghostscript interpreter/previewer.
ap   ispell       OPT   # ispell-3.1.08
ap   jed          OPT   # John E. Davis's JED 0.97-9 editor.
ap   joe          OPT   # Joe text editor, 2.2.
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.14.10)
ap   jpeg         OPT   # Independent JPEG Group's 5beta2 JPEG software
ap   manpgs       REC   # Man-pages 1.8 (on-line Linux documentation)
ap   mc           OPT   # Midnight Commander version 2.1
ap   mt_st        OPT   # mt-st-0.2 - controls magnetic tape drive operation
ap   sc           OPT   # The 'sc' spreadsheet. (v. 6.21)
ap   shlbsvga     REC   # Shared library libsvga.so.1.2.7 (from svgalib-127)
ap   sudo         OPT   # sudo 1.2
ap   termbin      OPT   # Term 2.3.5
ap   termnet      OPT   # Network utilities for term
ap   termsrc      OPT   # Term 2.3.5 source code
ap   texinfo      REC   # GNU texinfo-3.6
ap   vim          OPT   # Version 3.0 of Vim: Vi IMproved
ap   workbone     OPT   # Workbone 2.3
ap   zsh          OPT   # zsh version 2.4

d    *            SKP
d    binutils     ADD   # GNU binutils 2.5.2
d    bison        REC   # GNU bison parser generator version 1.22.
d    byacc        OPT   # Berkeley Yacc is an LALR(1) parser generator.  Berkeley Yacc
d    f2c          OPT   # A Fortran-77 to C translator.
d    flex         ADD   # flex - fast lexical analyzer generator version 2.5.2
d    gcc270       ADD   # The GNU C compiler and support files for ELF (v. 2.7.0)
d    gccaout      OPT   # The GNU C compiler and support files for the a.out format.
d    gcl          OPT   # GNU Common LISP 2.1
d    gdb          OPT   # The GNU debugger. (v. 4.14)
d    gmake        ADD   # GNU make utility 3.74.
d    gxx270       REC   # The GNU C++ compiler and support files for ELF (v. 2.7.0)
d    gxxaout      OPT   # The GNU C++ compiler and support files for the a.out format.
d    libaout      REC   # Libraries for the old a.out binary format.
d    libc         ADD   # Development libraries for the C compiler. (v. 5.0.9)
d    libcinfo     OPT   # C library documentation
d    libgxx       REC   # GNU libg++-2.6.2, Linux release 5
d    m4           ADD   # GNU m4 1.4
d    man2         REC   # Man pages for Linux system calls. (from manpages-1.8)
d    man3         REC   # Man pages for the C library functions. (from manpages-1.8)
d    ncurses      REC   # A curses-compatible screen management library with color. (v. 1.9.4)
d    objc270      OPT   # GNU compiler for the Objective-C language (v. 2.7.0)
d    p2c          OPT   # A Pascal to C translator. (v. 1.19)
d    perl         OPT   # Larry Wall's interpreted systems language. (v. 5.001m)
d    pmake        ADD   # BSD 4.4 make. This may be required if you're going to port software
d    rcs          OPT   # GNU revision control system.  (v. 5.7)
d    strace       OPT   # strace 3.0 - traces system calls and signals.
d    svgalib      OPT   # Svgalib Super-VGA Graphics Library (v1.2.7)
d    terminfo     OPT   # Complete /usr/lib/terminfo database.

e    *            SKP
e    elisp1       OPT   # Part one of the Lisp source files for Emacs 19.29.
e    elisp2       OPT   # Part two of the Lisp source files for Emacs 19.29.
e    elispc1      REC   # These are compiled lisp files for GNU Emacs 19.29 (part one).
e    elispc2      REC   # These are compiled lisp files for GNU Emacs 19.29 (part two).
e    emac_nox     OPT   # A replacement /usr/bin/emacs-19.29 binary that is not compiled with
e    emacinfo     REC   # Info files for emacs-19.29
e    emacmisc     REC   # Miscellaneous files for emacs 19.29.
e    emacsbin     ADD   # GNU Emacs 19.29

f    *            SKP
f    howto        ADD   # The collection of HOWTOs from the Linux Documentation Project.
f    manyfaqs     ADD   # A collection of frequently asked questions/answers on many subjects.

k    *            SKP
k    lx1213_1     REC   # Linux kernel source version 1.2.13, part one.
k    lx1213_2     REC   # Linux kernel source version 1.2.13, part two. (include files)
k    lx1213_3     REC   # Linux kernel source version 1.2.13, part three.
k    lx1320_1     OPT   # Linux kernel source version 1.3.20, part one.
k    lx1320_2     OPT   # Linux kernel source version 1.3.20, part two. (include files)
k    lx1320_3     OPT   # Linux kernel source version 1.3.20, part three.
k    lx1320_4     OPT   # Linux kernel source version 1.3.20, part four.

n    *            SKP
n    bind         REC   # BIND-4.9.3-beta9
n    cnews        OPT   # 20 Feb 1993 Performance Release of C News
n    deliver      OPT   # A small and simple program that delivers electronic mail once it
n    dip          OPT   # DIP - dialup IP connection handler 3.3.7n
n    elm          OPT   # Menu-driven user mail program. (v. 2.4pl23)
n    inn          OPT   # INN 1.4
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

q    *            SKP
q    aaztcd       OPT   # Linux kernel 1.3.18 (alpha) with Aztech/Orchid/Wearnes CD-ROM drivers.
q    abare        OPT   # Linux kernel 1.3.18 (alpha) with EIDE support.
q    acdu31a      OPT   # Linux kernel version 1.3.18 (alpha), with Sony CDU31A/CDU33A driver.
q    acdu535      OPT   # Linux kernel version 1.2.13 (alpha), with Sony 531/535 driver.
q    acm206       OPT   # Linux kernel 1.3.18 (alpha) with Phillips cm206 CD-ROM support.
q    agscd        OPT   # Linux kernel 1.3.18 (alpha) with GoldStar R420 CD-ROM support.
q    aha2940      OPT   # Linux kernel version 1.3.18 (alpha), with aha294x PCI SCSI support.
q    aidecd       OPT   # Linux kernel version 1.3.18 (alpha), with IDE/ATAPI CD-ROM support.
q    amitsumi     OPT   # Linux kernel version 1.3.18 (alpha), with Mitsumi CD support.
q    aoptcd       OPT   # Linux kernel 1.3.18 (alpha) with Optics Storage 8000 CD-ROM support.
q    asbpcd       OPT   # Linux kernel version 1.3.18 (alpha), with Soundblaster CD support.
q    ascsi        OPT   # Linux kernel version 1.3.18 (alpha), with SCSI + IDE support.
q    ascsint1     OPT   # Linux kernel version 1.3.18 (alpha), with SCSI + network support.
q    ascsint2     OPT   # Linux kernel version 1.3.18 (alpha), with SCSI + network support.
q    ascsint3     OPT   # Linux kernel version 1.3.18 (alpha), with SCSI + network support.
q    ascsint4     OPT   # Linux kernel version 1.3.18 (alpha), with SCSI + network support.
q    asjcd        OPT   # Linux kernel 1.3.18 (alpha) with Sanyo ISP16 CD-ROM support.
q    aztech1      OPT   # Linux kernel 1.2.13 with Aztech/Orchid/Wearnes CD-ROM drivers.
q    aztech2      OPT   # Linux kernel 1.2.13 with Aztech/Orchid/Wearnes CD-ROM drivers.
q    bare         OPT   # Linux kernel 1.2.13 with IDE hard drive support.
q    cdu31a1      OPT   # Linux kernel version 1.2.13, with Sony CDU31A/CDU33A driver.
q    cdu31a2      OPT   # Linux kernel version 1.2.13, with Sony CDU31A/CDU33A driver.
q    cdu535_1     OPT   # Linux kernel version 1.2.13, with Sony 531/535 driver.
q    cdu535_2     OPT   # Linux kernel version 1.2.13, with Sony 531/535 driver.
q    idecd1       OPT   # Linux kernel version 1.2.13, with IDE/ATAPI CD-ROM support.
q    idecd2       OPT   # Linux kernel version 1.2.13, with IDE/ATAPI CD-ROM support.
q    idenet       OPT   # Linux kernel version 1.2.13, with IDE and network drivers.
q    mitsumi1     OPT   # Linux kernel version 1.2.13, with SCSI+IDE+Mitsumi CD support.
q    mitsumi2     OPT   # Linux kernel version 1.2.13, with SCSI+IDE+Mitsumi CD support.
q    sbpcd1       OPT   # Linux kernel version 1.2.13, with SCSI+IDE+Soundblaster CD support.
q    sbpcd2       OPT   # Linux kernel version 1.2.13, with SCSI+IDE+Soundblaster CD support.
q    scsi         OPT   # Linux kernel version 1.2.13, with SCSI + IDE support.
q    scsinet1     OPT   # Linux kernel version 1.2.13, with SCSI + IDE support.
q    scsinet2     OPT   # Linux kernel version 1.2.13, with SCSI + IDE support.
q    xt           OPT   # Linux kernel version 1.2.13, with IDE+XT (MFM/RLL) drive support.

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
tcl  tcl          ADD   # The Tcl script language, version 7.4
tcl  tk           REC   # The Tk toolkit for Tcl, version 4.0

x    *            SKP
x    fnt100_1     OPT   # 100-dpi screen fonts (part one)
x    fnt100_2     OPT   # 100-dpi screen fonts (part two)
x    fntbig1      OPT   # Large fonts (part one)
x    fntbig2      OPT   # Large fonts (part two)
x    fntbig3      OPT   # Large fonts (part three)
x    fvwmicns     OPT   # Color icons from xpm3icons.tar.Z, found in the /pub/X11/contrib
x    oldlibs5     REC   # Shared X libraries from XFree86 2.1.1 (X11R5).
x    oldlibs6     REC   # a.out (DLL) format shared libraries for X11R6 binaries.
x    x3128514     REC   # An accelerated server for cards using IBM8514 chips.
x    x312agx      REC   # An accelerated server for IIT AGX-016, AGX-015, and AGX-014 chipsets.
x    x312bin      ADD   # Basic client binaries required for XFree86 3.1.2.
x    x312cfg      ADD   # Configuration files for XFree86 3.1.2.
x    x312ctrb     OPT   # Selected contrib programs for X11R6:
x    x312doc      OPT   # Documentation and release notes for XFree86 3.1.2.
x    x312f75      REC   # 75dpi Fonts for the X window system.
x    x312fcyr     OPT   # Cyrillic fonts for XFree86 3.1.2.
x    x312fnt      ADD   # Fonts for the X window system.
x    x312fscl     OPT   # Scaled fonts.
x    x312inc      REC   # Header files for X11 programming.
x    x312lib      ADD   # Dynamic libraries and configuration files for XFree86 3.1.2.
x    x312ma32     REC   # An accelerated server for cards using Mach32 chips.
x    x312ma64     REC   # An accelerated server for cards using the Mach64 chipset.
x    x312ma8      REC   # An accelerated server for cards using Mach8 chips.
x    x312man      REC   # Man pages for programs that come with XFree86 3.1.2.
x    x312mono     REC   # A Monochrome server.
x    x312p9k      REC   # An accelerated server for cards using the P9000 chipset.
x    x312s3       REC   # An accelerated server for cards using S3 chips.
x    x312svga     REC   # A server for SuperVGA video cards.
x    x312ubin     OPT   # Rstartd daemon.
x    x312vga      REC   # A server for 16 color EGA/VGA graphics modes.
x    x312w32      REC   # A server for chipsets in the ET4000/W32 series.
x    x312xtra     OPT   # Two optional experimental servers for X11R6.
x    xlock        ADD   # xlockmore-3.0
x    xpm          ADD   # The Xpm shared and static libraries, v. 3.4c (with libXpm.so.4.3)

xap  *            SKP
xap  gchess       OPT   # GNU chess (v. 4.00 patch level 69)
xap  ghstview     OPT   # Ghostview 1.5
xap  gnuplot      OPT   # gnuplot 3.5
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  libgr        REC   # libgr-1.3
xap  seyon        OPT   # Seyon 2.14c.
xap  x3270        OPT   # x3270 3.0.1.3 - IBM host access tool.
xap  xfileman     OPT   # xfilemanager 0.5
xap  xfm          OPT   # xfm 1.3.2, a file manager for X.
xap  xfract       OPT   # xfractint-3.00
xap  xgames       OPT   # A collection of games for X:
xap  xpaint       OPT   # XPaint 2.1
xap  xspread      OPT   # A spreadsheet for the X window system, version 2.1.
xap  xv           OPT   # John Bradley's XV 3.10 GIF/TIFF/JPEG/PostScript image viewer.
xap  xxgdb        OPT   # xxgdb-1.08.

xd   *            SKP
xd   x312pex      OPT   # XFree86 3.1.2 PEX distribution
xd   x312slib     OPT   # Static versions of the X libraries.
xd   xd_lkit1     OPT   # XFree86 3.1.2 Linkkit (part one)
xd   xd_lkit2     OPT   # XFree86 3.1.2 Linkkit (part two)
xd   xd_lkit3     OPT   # XFree86 3.1.2 Linkkit (part three)

xv   *            SKP
xv   sspkg        OPT   # SlingShot extensions 2.1
xv   workman      OPT   # WorkMan-1.2.2a
xv   xv32_a       OPT   # Static libraries for xview3.2p1-X11R6.
xv   xv32_so      ADD   # ELF shared libraries for xview3.2p1-X11R6.
xv   xv32exmp     OPT   # Sample code for XView
xv   xvinc32      OPT   # Include files for xview3.2p1-X11R6.
xv   xvmenus      ADD   # Menus and help files for the OpenLook Window Manager.
xv   xvol32       ADD   # Binaries for xview3.2p1-X11R6.

y    *            SKP
y    abuse1       OPT   # Abuse 0.31 (part one)
y    abuse2       OPT   # Abuse 0.31 (part two)
y    bsdgames     OPT   # Curtis Olson and Andy Tefft's port of the BSD games collection. (1.3)
y    doom         OPT   # Doom 1.8 for Linux
y    doomwad      OPT   # Part one of the wadfile for DOOM.
y    doomwad2     OPT   # Part two of the wadfile for DOOM.
y    sastroid     OPT   # Sasteroids 1.3
y    tetris       OPT   # Tetris for terminals.
