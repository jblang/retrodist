a    *            SKP
a    aaa_base     ADD   # Basic Linux filesystem package.
a    aoutlibs     ADD   # a.out (libc4) shared libraries
a    bash         ADD   # GNU bash-2.03
a    bash1        REC   # GNU bash-1.14.7
a    bin          ADD   # Binaries that go in /bin and /usr/bin.
a    bzip2        ADD   # bzip2 version 0.9.0c (a block-sorting file compressor)
a    cpio         ADD   # The GNU cpio backup and archiving utility v. 2.4.2
a    cxxlibs      ADD   # C++ shared libraries
a    devs         ADD   # Device files
a    e2fsprog     ADD   # e2fsprogs-1.15
a    elflibs      ADD   # Assorted ELF shared libraries
a    elvis        ADD   # elvis-2.1_4
a    etc          ADD   # /etc configuration files
a    fileutls     ADD   # fileutils-4.0
a    find         ADD   # GNU findutils-4.1
a    floppy       ADD   # floppy disk utilities
a    fsmods       ADD   # Filesystem modules for Linux 2.2.13
a    getty        OPT   # getty_ps 2.0.7j
a    glibcso      ADD   # glibc-2.1.2 runtime support
a    gpm          REC   # gpm-1.17.8
a    grep         ADD   # GNU grep 2.3
a    gzip         ADD   # GNU zip compression utilities. (v. 1.2.4a)
a    hdsetup      ADD   # The Slackware setup/package maintenance system v. 7.0.0
a    ibcs2        OPT   # Intel Binary Compatibility Specification module
a    ide          REC   # Linux kernel version 2.2.13, without SCSI support
a    infozip      ADD   # Info-ZIP's zip 2.2 and unzip 5.40 utilities
a    isapnp       OPT   # isapnptools-1.18
a    kbd          REC   # kbd-0.99
a    ldso         ADD   # ld.so 1.9.9, the dynamic linker/loader
a    less         ADD   # less-340
a    libc5        ADD   # Linux libc5 ELF shared libraries
a    lilo         ADD   # LILO 21
a    loadlin      REC   # LOADLIN v1.6a
a    lpr          REC   # lpr-0.35-6
a    man          ADD   # man-1.5g
a    minicom      REC   # Minicom 1.82-3
a    modules      ADD   # Linux kernel modules for 2.2.13
a    modutils     ADD   # modutils-2.1.121
a    pciutils     OPT   # pciutils-2.0 (Linux PCI utilities)
a    pcmcia       REC   # pcmcia-cs-3.0.14
a    procps       ADD   # procps-2.0.2, psmisc-18, procinfo-16
a    scsi         REC   # Linux kernel version 2.2.13, with SCSI support
a    scsimods     ADD   # Linux SCSI, RAID, and CD-ROM kernel modules for Linux 2.2.13
a    sh_utils     ADD   # GNU sh-utils-1.16
a    shadow       ADD   # Shadow password suite (shadow-19990607)
a    sysklogd     ADD   # Sysklogd 1.3-33
a    sysvinit     ADD   # sysvinit-2.76-4
a    tar          ADD   # GNU tar 1.13
a    tcsh         REC   # tcsh 6.08
a    txtutils     ADD   # GNU textutils-1.22
a    umsprogs     ADD   # umsdos-0.9
a    util         ADD   # util-linux 2.9v - A huge collection of essential utilities
a    zoneinfo     ADD   # time zone database

ap   *            SKP
ap   apsfilt      REC   # apsfilter-5.0.1.
ap   ash          OPT   # Kenneth Almquist's ash shell.
ap   bc           OPT   # GNU bc 1.05a - An arbitrary precision calculator language.
ap   cdutils      OPT   # Tools for mastering and writing compact discs.
ap   diff         REC   # GNU diffutils-2.7
ap   enscript     OPT   # GNU enscript 1.6.1
ap   ghostscr     REC   # Ghostscript version 5.10
ap   groff        ADD   # GNU troff 1.11a document formatting system.
ap   gsfonts      REC   # Fonts for the Ghostscript interpreter/previewer.
ap   ispell       OPT   # ispell-3.1.20
ap   jed          OPT   # John E. Davis's JED 0.98-7 editor.
ap   joe          OPT   # Joe text editor v2.8
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.14.10)
ap   manpages     REC   # Man-pages 1.24
ap   mc           OPT   # mc-4.5.39
ap   mt_st        OPT   # mt-st-0.4 - controls magnetic tape drive operation
ap   quota        OPT   # Linux disk quota utilities (1.70)
ap   raidtool     OPT   # raidtools-0.41
ap   rpm          OPT   # rpm-3.0.2
ap   sc           OPT   # The 'sc' spreadsheet. (v. 6.21)
ap   seejpeg      REC   # seejpeg-1.6.1
ap   sox          REC   # sox-12.15
ap   sudo         OPT   # sudo-1.5.9p4-1
ap   texinfo      REC   # GNU texinfo-3.12
ap   vim          OPT   # Version 5.5 of Vim: Vi IMproved
ap   workbone     OPT   # Workbone 2.31-5
ap   zsh          OPT   # zsh version 3.0.6

d    *            SKP
d    autoconf     OPT   # GNU autoconf 2.13
d    automake     OPT   # GNU automake 1.4
d    bin86        ADD   # bin86-0.4
d    binutils     ADD   # GNU binutils-2.9.1.0.25
d    bison        ADD   # GNU bison-1.27
d    byacc        OPT   # Berkeley Yacc
d    egcs         ADD   # The GNU C and C++ compilers (egcs-1.1.2).
d    egcs_g77     OPT   # GNU Fortran-77 compiler from the egcs-1.1.2 release.
d    egcsobjc     OPT   # GNU Objective-C compiler from the egcs-1.1.2 release.
d    flex         ADD   # flex - fast lexical analyzer generator version 2.5.4a
d    gcl          OPT   # GNU Common LISP 2.2.2
d    gdb          REC   # The GNU debugger. (v. 4.18)
d    gdbm         ADD   # GNU gdbm-1.7.3
d    gettext      ADD   # GNU gettext-0.10.35
d    glibc        ADD   # GNU glibc-2.1.2
d    gmake        ADD   # GNU make-3.77
d    jpeg6        REC   # Independent JPEG Group's JPEG software version 6b
d    libgr        REC   # libgr-2.0.13
d    libpng       REC   # libpng-1.0.3
d    libtiff      REC   # libtiff-3.4
d    libtool      OPT   # GNU libtool 1.3
d    linuxinc     ADD   # Linux 2.2.13 kernel include files
d    m4           REC   # GNU m4 1.4
d    ncurses      REC   # ncurses-5.0-990918
d    p2c          OPT   # p2c-1.21alpha2
d    perl         REC   # perl5.005_03
d    pmake        REC   # BSD pmake-4.4.
d    python       OPT   # python-1.5.2.
d    rcs          OPT   # GNU revision control system.  (v. 5.7)
d    readline     REC   # GNU readline-2.2.1
d    slang        REC   # slang-1.2.2
d    strace       REC   # strace-3.1.0.1 - traces system calls and signals.
d    svgalib      REC   # Svgalib Super-VGA Graphics Library 1.4.0
d    termcap      REC   # termcap-2.0.8
d    zlib         REC   # zlib-1.1.3

des  *            SKP
des  descrypt     ADD   # glibc-crypt-2.1.

e    *            SKP
e    elisp        OPT   # Emacs lisp source files.
e    emac_nox     OPT   # Emacs binary without X support.
e    emacinfo     REC   # Info files for emacs-20.4
e    emacmisc     REC   # Miscellaneous files for emacs-20.4.
e    emacsbin     ADD   # GNU Emacs 20.4

f    *            SKP
f    howto        ADD   # HOWTOs from the Linux Documentation Project.
f    manyfaqs     ADD   # A collection of frequently asked questions/answers on many subjects.
f    mini         ADD   # Linux Mini-HOWTOs.

gtk  *            SKP
gtk  audiofil     ADD   # audiofile-0.1.9
gtk  control      ADD   # control-center-1.0.51
gtk  econf        ADD   # enlightenment-conf-0.15
gtk  enlight      ADD   # enlightenment-0.15.5
gtk  esound       ADD   # esound-0.2.15
gtk  eterm        ADD   # Eterm-0.8.9
gtk  fnlib        ADD   # fnlib-0.4
gtk  freefont     ADD   # freefonts-0.10
gtk  freetype     ADD   # freetype-1.2
gtk  gdm          ADD   # gdm-2.0beta4
gtk  gedit        ADD   # gedit-0.5.1
gtk  gftp         ADD   # gftp-2.0.5
gtk  gimp         ADD   # The GIMP -- GNU Image Manipulation Program version 1.0.4
gtk  gmc          ADD   # mc-4.5.39
gtk  gnoadmin     ADD   # gnome-admin-1.0.3
gtk  gnoaudio     ADD   # gnome-audio-1.0.0
gtk  gnogames     ADD   # gnome-games-1.0.51
gtk  gnoguide     ADD   # users-guide-1.0.71
gtk  gnomcore     ADD   # gnome-core-1.0.53
gtk  gnomedia     ADD   # gnome-media-1.0.51
gtk  gnomeicu     ADD   # gnomeicu-0.65
gtk  gnomenet     ADD   # gnome-network-1.0.2
gtk  gnomepim     ADD   # gnome-pim-1.0.50
gtk  gnomlibs     ADD   # gnome-libs-1.0.53
gtk  gnomobjc     ADD   # gnome-objc-1.0.40
gtk  gnoprint     ADD   # gnome-print-0.9
gtk  gnotepad     ADD   # gnotepad+-1.0.8
gtk  gnoutils     ADD   # gnome-utils-1.0.50
gtk  gnpython     ADD   # gnome-python-1.0.50
gtk  gnumeric     ADD   # gnumeric-0.38
gtk  gtkeng       ADD   # gtk-engines-0.8
gtk  gtkglib      ADD   # gtk+-1.2.6, glib-1.2.6
gtk  guile        ADD   # guile-1.3.2a
gtk  imlib        ADD   # imlib-1.9.7
gtk  libghttp     ADD   # libghttp-1.0.4
gtk  libglade     ADD   # libglade-0.7
gtk  libgtop      ADD   # libgtop-1.0.5
gtk  libungif     ADD   # libungif-4.1.0
gtk  libxml       ADD   # libxml-1.7.3
gtk  orbit        ADD   # ORBit-0.5.0
gtk  wmaker       ADD   # WindowMaker-0.60.0
gtk  xchat        ADD   # xchat-1.2.1
gtk  xscrsave     ADD   # xscreensaver-3.17

k    *            SKP
k    linuxinc     REC   # Linux 2.2.13 kernel include files.
k    lx2213       REC   # Linux kernel source version 2.2.13.

kde  *            SKP
kde  kadmin       OPT   # kdeadmin-1.1.2
kde  kdebase      ADD   # kdebase-1.1.2 (KDE base package)
kde  kdegames     OPT   # kdegames-1.1.2
kde  kdelibs      ADD   # kdelibs-1.1.2
kde  kdetoys      OPT   # kdetoys-1.1.2
kde  kdeutils     REC   # kdeutils-1.1.2
kde  kgraphic     REC   # kdegraphics-1.1.2
kde  kmedia       OPT   # kdemultimedia-1.1.2
kde  knetwork     REC   # kdenetwork-1.1.2
kde  korganiz     OPT   # korganizer-1.1.2
kde  ksupport     ADD   # ksupport-1.1.2
kde  qt_1_44      ADD   # Qt-1.44

n    *            SKP
n    apache       OPT   # Apache WWW server v 1.3.9
n    bind         REC   # bind-8.2.2
n    dip          OPT   # DIP - dialup IP connection handler 3.3.7p
n    elm          OPT   # Menu-driven user mail program. (v. 2.5.1)
n    ftchmail     OPT   # fetchmail-5.1.2
n    imapd        OPT   # imapd-4.7-beta
n    inn          OPT   # INN-2.2.1
n    lynx         OPT   # Lynx 2.8.2rel.1
n    mailx        REC   # BSD mailx 8.1.1-10
n    metamail     REC   # metamail-2.7
n    netatalk     OPT   # netatalk-1.4b2+asun2.1.3
n    netmods      ADD   # Network support modules for linux-2.2.13.
n    netpipes     OPT   # netpipes 4.2
n    nn_nntp      OPT   # nn-6.5.1 compiled to use NNTP.
n    pine         OPT   # Pine version 4.20
n    ppp          OPT   # PPP for Linux, version 2.3.10
n    procmail     OPT   # The procmail mail processing program. (v3.13.1 1999/04/05)
n    rdist        OPT   # rdist-6.1.4.
n    rsync        OPT   # rsync-2.3.1
n    samba        OPT   # Samba 2.0.5a
n    sendmail     REC   # BSD sendmail 8.9.3.
n    smailcfg     OPT   # Configuration files for sendmail.
n    tcpip1       REC   # TCP/IP networking programs and support files.
n    tcpip2       REC   # Extra TCP/IP programs.
n    tin          OPT   # The 'tin' news reader. (tinpre-1.4-19990805)
n    trn          OPT   # A threaded news reader for reading a remote NNTP server. (v. 3.5)
n    uucp         OPT   # Taylor UUCP version 1.06.1
n    wget         OPT   # wget-1.5.3
n    xntp         OPT   # xntp3-5.93e

t    *            SKP
t    tetex        ADD   # teTeX-1.0.6 base support files.
t    tex_bin      ADD   # teTeX-1.0.6 binaries.
t    tex_doc      REC   # Documentation for teTeX-1.0.6.
t    transfig     OPT   # transfig 3.2.1.
t    xfig         OPT   # xfig 3.2.2.

tcl  *            SKP
tcl  expect       OPT   # expect-5.28.
tcl  hfsutils     OPT   # hfsutils-3.2.6.
tcl  tcl          ADD   # The Tcl script language, version 8.0.5.
tcl  tclx         REC   # Extended Tcl (TclX) 8.0.4.
tcl  tix          OPT   # Tix4.1.0.006.
tcl  tk           REC   # The Tk toolkit for Tcl, version 8.0.5.

x    *            SKP
x    fvwm2        ADD   # fvwm-2.2.2
x    fvwmicns     OPT   # xpm3icons.
x    lesstif      REC   # LessTif 0.89.0 (A Motif 1.2 alternative)
x    libc5x       OPT   # ELF libc5 shared libraries from XFree86 3.3.3.1.
x    mesa         ADD   # Mesa-3.0
x    oldlibs5     OPT   # a.out (libc4) libraries from XFree86 2.1.1 (X11R5).
x    oldlibs6     OPT   # a.out (libc4) libraries from XFree86 3.1.1 (X11R6).
x    x3dl         REC   # An accelerated server for 3DLabs chipsets.
x    x8514        REC   # An accelerated server for cards using IBM8514 chips.
x    xagx         REC   # An accelerated server for IIT AGX chipsets.
x    xaw3d        ADD   # Xaw3d-1.4
x    xbin         ADD   # Basic client binaries required for XFree86 3.3.5.
x    xcfg         ADD   # Configuration files for XFree86 3.3.5.
x    xdoc         REC   # Documentation and release notes for XFree86 3.3.5.
x    xf100        OPT   # 100-dpi screen fonts.
x    xfcyr        OPT   # Cyrillic fonts for XFree86 3.3.5.
x    xfnon        OPT   # Some large X fonts.
x    xfnts        ADD   # Fonts for the X window system.
x    xfscl        OPT   # Scaled fonts.
x    xfsrv        OPT   # xfs (X font server)
x    xhtml        OPT   # Docs for XFree86 in HTML format.
x    xi128        REC   # A server for the Number Nine Imagine 128.
x    xjdoc        OPT   # Japanese documentation and release notes for XFree86 3.3.5.
x    xjset        OPT   # Japanese configuration utility for XFree86.
x    xlib         ADD   # Various library files for XFree86 3.3.5.
x    xlock        ADD   # xlockmore-4.14
x    xma32        REC   # An accelerated server for cards using Mach32 chips.
x    xma64        REC   # An accelerated server for cards using the Mach64 chipset.
x    xma8         REC   # An accelerated server for cards using Mach8 chips.
x    xman         REC   # Man pages for XFree86 3.3.5.
x    xmono        REC   # A Monochrome server.
x    xnest        OPT   # Xnest - a nested X server.
x    xp9k         REC   # An accelerated server for cards using the P9000 chipset.
x    xpm          ADD   # The Xpm shared and static libraries, v. 3.4k (with libXpm.so.4.11)
x    xprog        REC   # Libraries, include files, and configuration files for X programming.
x    xprt         OPT   # Print-only server (Xprt) for XFree86 3.3.5.
x    xps          OPT   # XFree86 documentation in PostScript format.
x    xs3          REC   # An accelerated server for cards using S3 chips.
x    xs3v         REC   # An accelerated server for cards using S3 ViRGE chips.
x    xset         REC   # Graphical configuration utility for XFree86.
x    xsvga        REC   # A server for many SuperVGA video cards.
x    xvfb         OPT   # Virtual framebuffer X server.
x    xvg16        REC   # A server for 16 color EGA/VGA graphics modes.
x    xw32         REC   # A server for chipsets in the ET4000/W32 series.
x    xxfb         REC   # Frame buffer X server.

xap  *            SKP
xap  fvwm95       REC   # fvwm95-2.0.43b
xap  gnuchess     REC   # gnuchess-4.0.pl80 and xboard-4.0.2
xap  gnuplot      OPT   # gnuplot 3.7
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  gv           REC   # gv 3.5.8
xap  imagick      REC   # ImageMagick-4.2.2
xap  netscape     REC   # Netscape Communicator 4.7 (v47.x86-unknown-linuxglibc2.0)
xap  seyon        OPT   # Seyon 2.14c.
xap  tkdesk       OPT   # TkDesk 1.1
xap  x3270        OPT   # x3270-3.1.1.6 - IBM host access tool.
xap  xfm          OPT   # xfm 1.3.2, a file manager for X.
xap  xfract       REC   # xfractint-3.04
xap  xgames       REC   # xgames collection
xap  xpaint       OPT   # XPaint 2.4.9.
xap  xpdf         OPT   # xpdf-0.7a
xap  xspread      OPT   # xspread-2.3
xap  xv           REC   # John Bradley's XV 3.10a GIF/TIFF/JPEG/PostScript image viewer.
xap  xvim         REC   # X enabled version of vim-5.5
xap  xxgdb        REC   # xxgdb-1.12.

xd   *            SKP
xd   xlkit        OPT   # XFree86 3.3.5 server linkkit.

xv   *            SKP
xv   sspkg        OPT   # SlingShot extensions 2.1
xv   workman      OPT   # WorkMan-1.3a
xv   xv32_a       OPT   # Static libraries for xview3.2p1-X11R6.LinuxELF.4
xv   xv32exmp     OPT   # Sample code for XView
xv   xvinc32      OPT   # Include files for xview3.2p1-X11R6.LinuxELF.4
xv   xvol32       ADD   # Binaries for xview3.2p1-X11R6.LinuxELF.4

y    *            SKP
y    bsdgames     OPT   # BSD games collection, version 2.7.
y    koules       OPT   # Koules 1.4
y    lizards      OPT   # Lizards -- a video game for Linux.
y    sastroid     OPT   # Sasteroids 1.3
