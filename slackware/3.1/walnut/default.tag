a    *            SKP
a    aaa_base     ADD   # Basic Linux filesystem package.
a    aoutlibs     ADD   # a.out shared libraries:
a    bash         ADD   # GNU bash-1.14.6
a    bin          ADD   # Binaries that go in /bin and /usr/bin.
a    comms        REC   # Serial file-transfer and communication packages.
a    cpio         ADD   # The GNU cpio backup and archiving utility v. 2.3
a    devs         ADD   # Device files.
a    e2fsbn       ADD   # Utilities for the second extended file system v. 1.04
a    elflibs      ADD   # ELF shared libraries.
a    etc          ADD   # System configuration files that go into the /etc directory.
a    find         ADD   # GNU findutils-4.1
a    getty        OPT   # getty_ps 2.0.7i
a    gpm          REC   # General purpose mouse support v1.09
a    grep         ADD   # GNU grep 2.0
a    gzip         ADD   # GNU zip compression utilities. (v. 1.2.4)
a    hdsetup      ADD   # The Slackware setup/package maintenance system v. 3.1.0
a    ibcs2        OPT   # Intel Binary Compatibility Specification module
a    ide          REC   # Linux kernel version 2.0.0, without SCSI support.
a    keytbls      OPT   # kbd 0.90
a    ldso         ADD   # ld.so 1.7.14, the dynamic linker/loader.
a    less         ADD   # less-290
a    lilo         ADD   # LILO 19
a    loadlin      REC   # LOADLIN v1.6
a    modules      ADD   # Linux kernel modules for 2.0.0.
a    pcmcia       OPT   # pcmcia-cs-2.8.17
a    ps           ADD   # procps 0.99a
a    scsi         REC   # Linux kernel version 2.0.0, with SCSI support.
a    sh_utils     ADD   # GNU sh-utils-1.12
a    sysklogd     ADD   # Sysklogd 1.2
a    sysvinit     ADD   # SysVinit v. 2.62
a    tar          ADD   # GNU tar 1.11.8
a    tcsh         OPT   # tcsh 6.06
a    txtutils     ADD   # GNU textutils-1.13
a    umsprogs     ADD   # umsdos_progs 0.8
a    util         ADD   # util-linux 2.5
a    zoneinfo     ADD   # Time zone utilities

ap   *            SKP
ap   ash          OPT   # Kenneth Almquist's ash shell.
ap   bc           OPT   # GNU bc 1.03 - An arbitrary precision calculator language.
ap   diff         REC   # GNU diffutils-2.7
ap   ghostscr     OPT   # Ghostscript version 2.6.2
ap   gp9600       OPT   # Change the default modem speed from 9600 baud.
ap   groff        ADD   # GNU troff 1.10 document formatting system.
ap   gsfonts1     OPT   # Fonts for the Ghostscript interpreter/previewer, part one.
ap   gsfonts2     OPT   # Fonts for the Ghostscript interpreter/previewer, part two.
ap   ispell       OPT   # ispell-3.1.20
ap   jed          OPT   # John E. Davis's JED 0.97-14 editor.
ap   joe          OPT   # Joe text editor, 2.2.
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.14.10)
ap   jpeg         OPT   # Independent JPEG Group's 5beta2 JPEG software
ap   manpgs       REC   # Man-pages 1.8 (on-line Linux documentation)
ap   mc           OPT   # Midnight Commander version 3.2.1.
ap   mt_st        OPT   # mt-st-0.4 - controls magnetic tape drive operation
ap   quota        OPT   # Linux disk quota utilities (1.51)
ap   sc           OPT   # The 'sc' spreadsheet. (v. 6.21)
ap   sudo         OPT   # sudo 1.2
ap   texinfo      REC   # GNU texinfo-3.6
ap   vim          OPT   # Version 3.0 of Vim: Vi IMproved
ap   workbone     OPT   # Workbone 2.3
ap   zsh          OPT   # zsh version 2.6.10

d    *            SKP
d    binutils     ADD   # GNU binutils 2.6.0.14
d    bison        REC   # GNU bison parser generator version 1.22.
d    byacc        OPT   # Berkeley Yacc is an LALR(1) parser generator.  Berkeley Yacc
d    flex         ADD   # flex - fast lexical analyzer generator version 2.5.3
d    g77          OPT   # GNU Fortran-77 compiler, version 0.5.18.
d    gcc272       ADD   # The GNU C compiler and support files for ELF (v. 2.7.2)
d    gccaout      OPT   # The GNU C compiler and support files for the a.out format.
d    gcl          OPT   # GNU Common LISP 2.2
d    gdb          OPT   # The GNU debugger. (v. 4.15.1)
d    gmake        ADD   # GNU make utility 3.74.
d    gxx272       REC   # The GNU C++ compiler and support files for ELF (v. 2.7.2)
d    gxxaout      OPT   # The GNU C++ compiler and support files for the a.out format.
d    libaout      REC   # Libraries for the old a.out binary format. (libc-4.7.6)
d    libc         ADD   # Development libraries for the C compiler.
d    libcinfo     OPT   # C library documentation
d    libgxx       REC   # GNU libg++-2.7.1.4
d    linuxinc     ADD   # Linux 2.0.0 kernel include files
d    m4           ADD   # GNU m4 1.4
d    man2         REC   # Man pages for Linux system calls. (from manpages-1.8)
d    man3         REC   # Man pages for the C library functions. (from manpages-1.8)
d    ncurses      REC   # A curses-compatible screen management library with color. (v. 1.9.9e)
d    objc272      OPT   # GNU compiler for the Objective-C language (v. 2.7.2)
d    objcaout     OPT   # The GNU Objective-C compiler and support files for the a.out format.
d    p2c          OPT   # A Pascal to C translator. (v. 1.19)
d    perl1        OPT   # Larry Wall's interpreted systems language, part one. (v. 5.003)
d    perl2        OPT   # Larry Wall's interpreted systems language, part two. (v. 5.003)
d    pmake        ADD   # BSD 4.4 make.
d    rcs          OPT   # GNU revision control system.  (v. 5.7)
d    strace       OPT   # strace 3.0 - traces system calls and signals.
d    svgalib      OPT   # Svgalib Super-VGA Graphics Library 1.2.10
d    terminfo     OPT   # Complete /usr/lib/terminfo database.
d    tools        OPT   # tools 2.17

e    *            SKP
e    elisp1       OPT   # Part one of the Lisp source files for Emacs 19.31.
e    elisp2       OPT   # Part two of the Lisp source files for Emacs 19.31.
e    elisp3       OPT   # Part three of the Lisp source files for Emacs 19.31.
e    elisp4       OPT   # Part four of the Lisp source files for Emacs 19.31.
e    elispc1      REC   # These are compiled lisp files for GNU Emacs 19.31 (part one).
e    elispc2      REC   # These are compiled lisp files for GNU Emacs 19.31 (part two).
e    elispc3      REC   # These are compiled lisp files for GNU Emacs 19.31 (part three).
e    emac_nox     OPT   # A replacement /usr/bin/emacs-19.31 binary that is not compiled with
e    emacinfo     REC   # Info files for emacs-19.31
e    emacmisc     REC   # Miscellaneous files for emacs 19.31.
e    emacsbin     ADD   # GNU Emacs 19.31

f    *            SKP
f    howto        ADD   # The collection of HOWTOs from the Linux Documentation Project.
f    manyfaqs     ADD   # A collection of frequently asked questions/answers on many subjects.

k    *            SKP
k    lx200_1      REC   # Linux kernel source version 2.0.0, part one.
k    lx200_2      REC   # Linux kernel source version 2.0.0, part two.
k    lx200_3      REC   # Linux kernel source version 2.0.0, part three.
k    lx200_4      REC   # Linux kernel source version 2.0.0, part four.
k    lx200_5      REC   # Linux kernel source version 2.0.0, part five.
k    lx200_6      REC   # Linux kernel source version 2.0.0, part six.

n    *            SKP
n    apache       OPT   # Apache WWW server v 1.0.0
n    bind         REC   # BIND-4.9.3-BETA26
n    cnews        OPT   # 20 Feb 1993 Performance Release of C News
n    dip          OPT   # DIP - dialup IP connection handler 3.3.7n
n    elm          OPT   # Menu-driven user mail program. (v. 2.4pl25)
n    inn          OPT   # INN 1.4
n    lynx         OPT   # Lynx 2.5
n    mailx        REC   # BSD mailx 5.5.
n    metamail     REC   # metamail-2.7
n    netpipes     OPT   # netpipes 3.1
n    nn-nntp      OPT   # nn-6.4.18 compiled to use NNTP.
n    nn-spool     OPT   # nn-6.4.18 compiled to use a local news spool.
n    pine         OPT   # Pine version 3.93
n    ppp          OPT   # PPP for Linux, version 2.1.2b and 2.2.0f
n    procmail     OPT   # The procmail mail processing program. (v3.10 1994/10/31)
n    rdist        OPT   # Remote file distribution program.
n    sendmail     REC   # BSD sendmail 8.7.5.
n    smailcfg     OPT   # Configuration files for sendmail.
n    tcpip        REC   # TCP/IP networking programs and support files.
n    tin          OPT   # The 'tin' news reader. (1.2pl2)
n    trn          OPT   # A threaded news reader for the local news spool. (v. 3.5)
n    trn-nntp     OPT   # A threaded news reader for reading a remote NNTP server. (v. 3.5)
n    uucp         OPT   # Taylor UUCP version 1.06.1

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
tcl  tcl          ADD   # The Tcl script language, version 7.5
tcl  tclx         REC   # Extended Tcl (TclX) 7.5.0.
tcl  tk           REC   # The Tk toolkit for Tcl, version 4.1
tcl  tkdesk       OPT   # TkDesk 1.0a2

x    *            SKP
x    fnt100_1     OPT   # 100-dpi screen fonts, part one.
x    fnt100_2     OPT   # 100-dpi screen fonts, part two.
x    fntbig1      OPT   # Large fonts, part one.
x    fntbig2      OPT   # Large fonts, part two.
x    fntbig3      OPT   # Large fonts, part three.
x    fvwmicns     OPT   # Color icons from xpm3icons.tar.Z, found in the /pub/X11/contrib
x    oldlibs5     REC   # Shared X libraries from XFree86 2.1.1 (X11R5).
x    oldlibs6     REC   # a.out (DLL) format shared libraries for X11R6 binaries.
x    x3128514     REC   # An accelerated server for cards using IBM8514 chips.
x    x312agx      REC   # An accelerated server for IIT AGX-016, AGX-015, and AGX-014 chipsets.
x    x312bin      ADD   # Basic client binaries required for XFree86 3.1.2.
x    x312cfg      ADD   # Configuration files for XFree86 3.1.2.
x    x312ctrb     OPT   # Selected contributed programs for X11R6:
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
x    xlock        ADD   # xlockmore-3.9
x    xpm          ADD   # The Xpm shared and static libraries, v. 3.4c (with libXpm.so.4.3)

xap  *            SKP
xap  arena        OPT   # Arena beta-2b
xap  fvwm95       OPT   # fvwm95-2.0.41f
xap  gchess       OPT   # GNU chess (v. 4.00 patch level 69)
xap  ghstview     OPT   # Ghostview 1.5
xap  gnuplot      OPT   # gnuplot 3.5
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  libgr        REC   # libgr-1.3
xap  seyon        OPT   # Seyon 2.14c.
xap  x3270        OPT   # x3270 3.1.0.5 - IBM host access tool.
xap  xfileman     OPT   # xfilemanager 0.5
xap  xfm          OPT   # xfm 1.3.2, a file manager for X.
xap  xfract       OPT   # xfractint-3.00
xap  xgames       OPT   # A collection of games for X:
xap  xpaint       OPT   # XPaint 2.1
xap  xspread      OPT   # A spreadsheet for the X window system, version 2.1.
xap  xv           OPT   # John Bradley's XV 3.10 GIF/TIFF/JPEG/PostScript image viewer.
xap  xxgdb        OPT   # xxgdb-1.12.

xd   *            SKP
xd   x312pex      OPT   # XFree86 3.1.2 PEX distribution
xd   x312slib     OPT   # Static versions of the X libraries.
xd   xd_lkit1     OPT   # XFree86 3.1.2 server linkkit, part one.
xd   xd_lkit2     OPT   # XFree86 3.1.2 server linkkit, part two.
xd   xd_lkit3     OPT   # XFree86 3.1.2 server linkkit, part three.

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
y    tetris       OPT   # Tetris for terminals.
