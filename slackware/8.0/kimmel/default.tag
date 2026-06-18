a    *            SKP
a    aaa_base     ADD   # Basic Linux filesystem package.
a    bash         ADD   # GNU bash-2.05
a    bash1        REC   # GNU bash-1.14.7
a    bin          ADD   # Binaries that go in /bin and /usr/bin.
a    bzip2        ADD   # bzip2 version 1.0.1 (a block-sorting file compressor)
a    cpio         ADD   # The GNU cpio backup and archiving utility v. 2.4.2
a    cxxlibs      ADD   # C++ shared libraries
a    devfsd       ADD   # devfsd-v1.3.11
a    devs         ADD   # Device files
a    e2fsprog     ADD   # e2fsprogs-1.22
a    elflibs      ADD   # Assorted ELF shared libraries
a    elvis        ADD   # elvis-2.1_4
a    etc          ADD   # /etc configuration files
a    fileutls     ADD   # fileutils-4.1
a    find         ADD   # GNU findutils-4.1
a    floppy       ADD   # floppy disk utilities
a    getty        OPT   # getty_ps 2.0.7j
a    glibcso      ADD   # glibc-2.2.3 runtime support
a    gpm          REC   # gpm-1.19.3
a    grep         ADD   # GNU grep 2.4.2
a    gzip         ADD   # GNU zip compression utilities. (v. 1.2.4a)
a    hdsetup      ADD   # The Slackware setup/package maintenance system v. 8.0.0
a    i245         REC   # Linux kernel version 2.4.5, without SCSI support
a    ide          REC   # Linux kernel version 2.2.19, without SCSI support
a    infozip      ADD   # Info-ZIP's zip 2.3 and unzip 5.41 utilities
a    isapnp       OPT   # isapnptools-1.21
a    kbd          REC   # kbd-1.06
a    less         ADD   # less-358
a    lilo         ADD   # LILO 21.7.5
a    loadlin      REC   # LOADLIN v1.6b
a    lpr          REC   # lpr-0.48-1
a    minicom      REC   # Minicom 1.83.1
a    mods245      ADD   # Linux kernel modules for 2.4.5
a    modules      ADD   # Linux kernel modules for 2.2.19
a    modutils     ADD   # modutils-2.4.6
a    ossllibs     ADD   # openssl-0.9.6a shared libraries
a    pciutils     OPT   # pciutils-2.1.8 (Linux PCI utilities)
a    pcmcia       REC   # pcmcia-cs-3.1.26
a    procps       ADD   # procps-2.0.7, psmisc-20.1, procinfo-18
a    reiserfs     ADD   # reiserfsprogs-3.x.0j
a    sc245        REC   # Linux kernel version 2.4.5, with SCSI support
a    scsi         REC   # Linux kernel version 2.2.19, with SCSI support
a    sh_utils     ADD   # GNU sh-utils-2.0
a    shadow       ADD   # Shadow password suite (shadow-19990607)
a    sysklogd     ADD   # Sysklogd 1.4.1
a    sysvinit     ADD   # sysvinit-2.78
a    tar          ADD   # GNU tar 1.13
a    tcsh         REC   # tcsh 6.10
a    txtutils     ADD   # GNU textutils-2.0
a    umsprogs     ADD   # umsdos-progs-1.13
a    util         ADD   # util-linux 2.11f - A huge collection of essential utilities
a    zoneinfo     ADD   # time zone database

ap   *            SKP
ap   a2ps         REC   # GNU a2ps-4.13b.
ap   apsfilt      REC   # apsfilter-6.1.1.
ap   ash          OPT   # Kenneth Almquist's ash shell.
ap   bc           OPT   # GNU bc 1.06 - An arbitrary precision calculator language.
ap   cdparano     OPT   # cdparanoia-III-alpha9.8
ap   cdrdao       OPT   # cdrdao-1.1.5
ap   cdrtools     OPT   # cdrtools-1.10
ap   diff         REC   # GNU diffutils-2.7
ap   enscript     OPT   # GNU enscript 1.6.1
ap   ghostscr     REC   # Ghostscript version 5.50a
ap   groff        ADD   # GNU groff 1.17 document formatting system.
ap   gsfonts      REC   # Fonts for the Ghostscript interpreter/previewer.
ap   ispell       OPT   # ispell-3.2.03
ap   jed          OPT   # jed-B0.99-12
ap   joe          OPT   # Joe text editor v2.9.5
ap   jove         OPT   # Jonathan's Own Version of Emacs (4.16)
ap   ksh93        OPT   # AT&T Korn Shell 93 (2001-01-01.0000)
ap   lvm          OPT   # lvm_0.9.1_beta6
ap   man          ADD   # man-1.5h1
ap   manpages     REC   # Man-pages 1.38
ap   mc           OPT   # mc-4.5.51
ap   mp3          OPT   # MP3 players
ap   mt_st        OPT   # mt-st-0.6 - controls magnetic tape drive operation
ap   mysql        OPT   # mysql-3.23.39
ap   oggutils     OPT   # Ogg Vorbis libraries and tools
ap   quota        OPT   # Linux disk quota utilities (2.00)
ap   raidtool     OPT   # raidtools-19990824-0.90.
ap   rpm          OPT   # rpm-4.0.2
ap   sc           OPT   # The 'sc' spreadsheet. (v. 7.7)
ap   screen       OPT   # GNU screen-3.9.9
ap   seejpeg      REC   # seejpeg-1.10
ap   sox          REC   # sox-12.17.1
ap   sudo         OPT   # sudo-1.6.3p7
ap   texinfo      REC   # GNU texinfo-4.0
ap   vim          OPT   # Version 5.8 of Vim: Vi IMproved
ap   workbone     OPT   # Workbone 2.40-2
ap   zsh          OPT   # zsh version 4.0.1

d    *            SKP
d    autoconf     OPT   # GNU autoconf 2.50
d    automake     OPT   # GNU automake 1.4-p4
d    bin86        ADD   # bin86-0.15.5
d    binutils     ADD   # GNU binutils-2.11.90.0.19
d    bison        ADD   # GNU bison-1.28
d    byacc        OPT   # Berkeley Yacc
d    cvs          REC   # cvs-1.11.1p1 - Concurrent Versions System
d    egcs         ADD   # The egcs-1.1.2 C compiler.
d    flex         ADD   # flex - fast lexical analyzer generator version 2.5.4a
d    gcc          ADD   # The GNU C and C++ compilers (gcc-2.95.3).
d    gcc_g77      OPT   # GNU Fortran-77 compiler from the gcc-2.95.3 release.
d    gcc_objc     OPT   # GNU Objective-C compiler from the gcc-2.95.3 release.
d    gcl          OPT   # GNU Common LISP 2.4.0
d    gdb          REC   # The GNU debugger. (v. 5.0)
d    gdbm         ADD   # GNU gdbm-1.8.0
d    gettext      ADD   # GNU gettext-0.10.38
d    glibc        ADD   # GNU glibc-2.2.3
d    glocale      OPT   # locale files from glibc-2.2.3
d    gmake        ADD   # GNU make-3.79.1
d    jpeg6        REC   # Independent JPEG Group's JPEG software version 6b
d    libgr        REC   # libgr-2.0.13
d    libpng       REC   # libpng-1.0.11
d    libtiff      REC   # libtiff-3.5.5
d    libtool      OPT   # GNU libtool 1.4
d    linuxinc     ADD   # Linux 2.2.19 kernel include files
d    m4           REC   # GNU m4 1.4
d    ncurses      REC   # ncurses-5.2
d    p2c          OPT   # p2c-1.21alpha2
d    perl         REC   # perl-5.6.1
d    pmake        REC   # pmake-2.1.34
d    python       OPT   # python-2.0.1
d    rcs          OPT   # GNU revision control system.  (v. 5.7)
d    readline     REC   # GNU readline-4.1
d    slang        REC   # slang-1.4.3
d    strace       REC   # strace-4.2 - traces system calls and signals.
d    svgalib      REC   # Svgalib Super-VGA Graphics Library 1.4.3
d    termcap      REC   # termcap-2.0.8
d    zlib         REC   # zlib-1.1.3

e    *            SKP
e    elisp        OPT   # Emacs lisp source files.
e    emac_nox     OPT   # Emacs binary without X support.
e    emacinfo     REC   # Info files for emacs-20.7
e    emacleim     OPT   # leim-20.7 (Library of Emacs Input Method)
e    emacmisc     REC   # Miscellaneous files for emacs-20.7.
e    emacsbin     ADD   # GNU Emacs 20.7

f    *            SKP
f    howto        ADD   # HOWTOs from the Linux Documentation Project.
f    manyfaqs     ADD   # A collection of frequently asked questions/answers on many subjects.
f    mini         ADD   # Linux Mini-HOWTOs.

gtk  *            SKP
gtk  aaagnome     ADD   # GNOME/GTK+ preparation package
gtk  abi          OPT   # AbiWord Personal (abi-0.7.14-2)
gtk  audiofil     ADD   # audiofile-0.2.1
gtk  bonobo       ADD   # bonobo-1.0.4
gtk  bugbuddy     OPT   # bug-buddy-2.0.1
gtk  control      ADD   # control-center-1.4.0.1
gtk  ee           OPT   # ee-0.3.12
gtk  enlight      OPT   # enlightenment-0.16.5.
gtk  eog          OPT   # eog-0.6
gtk  esound       ADD   # esound-0.2.22
gtk  eterm        REC   # Eterm-0.8.10
gtk  fnlib        ADD   # fnlib-0.5
gtk  gal          ADD   # gal-0.8
gtk  galeon       REC   # galeon-0.11.0
gtk  gconf        ADD   # GConf-1.0.1
gtk  gdkpixbf     ADD   # gdk-pixbuf-0.10.1
gtk  gdm          ADD   # gdm-2.2.2.1
gtk  gedit        REC   # gedit-0.9.6
gtk  gftp         REC   # gftp-2.0.8
gtk  ggv          REC   # ggv-1.0.1
gtk  ghex         REC   # ghex-1.2
gtk  gimp         REC   # The GIMP -- GNU Image Manipulation Program version 1.2.1
gtk  gimplibs     REC   # Extra libraries for the GIMP
gtk  gladedev     REC   # glade-0.6.2
gtk  glib         ADD   # glib-1.2.10
gtk  gmp          ADD   # gmp-3.1.1
gtk  gnoadmin     REC   # gnome-admin-1.0.3
gtk  gnoaudio     REC   # gnome-audio-1.4.0
gtk  gnogames     REC   # gnome-games-1.4.0.1
gtk  gnomapps     ADD   # gnome-applets-1.4.0.1
gtk  gnomcore     ADD   # gnome-core-1.4.0.4
gtk  gnomedia     REC   # gnome-media-1.2.3
gtk  gnomeicu     REC   # gnomeicu-0.96.1
gtk  gnomemm      ADD   # gnomemm-1.1.16
gtk  gnomenet     REC   # gnome-network-1.0.2
gtk  gnomepim     REC   # gnome-pim-1.4.0
gtk  gnometop     REC   # gtop-1.0.13
gtk  gnomevfs     ADD   # gnome-vfs-1.0.1, gnome-vfs-extras-0.1.1
gtk  gnomlibs     ADD   # gnome-libs-1.2.13
gtk  gnomobjc     REC   # gnome-objc-1.0.40
gtk  gnoprint     ADD   # gnome-print-0.29
gtk  gnotepad     OPT   # gnotepad+-1.3.3
gtk  gnoutils     ADD   # gnome-utils-1.4.0.1
gtk  gnpython     REC   # gnome-python-1.4.1
gtk  gnumeric     REC   # gnumeric-0.65
gtk  gqmpeg       OPT   # gqmpeg-0.6.3
gtk  gtkeng       ADD   # gtk-engines-0.12
gtk  gtkhtml      ADD   # gtkhtml-0.9.2
gtk  gtkmm        ADD   # gtkmm-1.2.5
gtk  gtkplus      ADD   # gtk+-1.2.10
gtk  gtm          REC   # gtm-0.4.9
gtk  guile        ADD   # guile-1.4
gtk  imlib        ADD   # imlib-1.9.10
gtk  libghttp     ADD   # libghttp-1.0.9
gtk  libglade     ADD   # libglade-0.16
gtk  libgtop      ADD   # libgtop-1.0.12
gtk  libole2      ADD   # libole2-0.2.3.
gtk  librep       ADD   # librep-0.13.6
gtk  libsigc      ADD   # libsigc++-1.0.3
gtk  libungif     ADD   # libungif-4.1.0
gtk  libxml1      ADD   # libxml-1.8.13
gtk  lunicode     ADD   # libunicode-0.4
gtk  mozilla      ADD   # mozilla-0.9.1
gtk  nautilus     ADD   # nautilus-1.0.3
gtk  oaf          ADD   # oaf-0.6.5
gtk  orbit        ADD   # ORBit-0.5.8
gtk  pan          REC   # pan-0.9.7
gtk  panelmm      ADD   # panelmm-0.1
gtk  repgtk       ADD   # rep-gtk-0.15
gtk  sawfish      ADD   # sawfish-0.38
gtk  scrollkp     ADD   # scrollkeeper-0.2
gtk  userdocs     REC   # gnome-user-docs-1.4.1
gtk  wmaker       OPT   # WindowMaker-0.65.0
gtk  xalf         ADD   # xalf-0.12
gtk  xchat        OPT   # xchat-1.6.4
gtk  xmms         OPT   # xmms-1.2.5
gtk  xscrsave     OPT   # xscreensaver-3.32
gtk  xvim         OPT   # X enabled version of vim-5.8

k    *            SKP
k    lnx245       REC   # Linux kernel source version 2.4.5
k    lx2219       REC   # Linux kernel source version 2.2.19.

kde  *            SKP
kde  htdig        ADD   # htdig-3.1.5
kde  kadmin       REC   # kdeadmin-2.1.1
kde  kdebase      ADD   # kdebase-2.1.1 (KDE base package)
kde  kdegames     OPT   # kdegames-2.1.1
kde  kdelibs      ADD   # kdelibs-2.1.2
kde  kdepim       OPT   # kdepim-2.1.1
kde  kdesdk       OPT   # kdesdk-2.1.1
kde  kdetoys      OPT   # kdetoys-2.1.1
kde  kdeutils     REC   # kdeutils-2.1.1
kde  kdevelop     OPT   # kdevelop-1.4.1
kde  kdi-ca       OPT   # kde-i18n-ca-2.1.1
kde  kdi-cs       OPT   # kde-i18n-cs-2.1.1
kde  kdi-da       OPT   # kde-i18n-da-2.1.1
kde  kdi-de       OPT   # kde-i18n-de-2.1.1
kde  kdi-el       OPT   # kde-i18n-el-2.1.1
kde  kdi-eo       OPT   # kde-i18n-eo-2.1.1
kde  kdi-es       OPT   # kde-i18n-es-2.1.1
kde  kdi-et       OPT   # kde-i18n-et-2.1.1
kde  kdi-fi       OPT   # kde-i18n-fi-2.1.1
kde  kdi-fr       OPT   # kde-i18n-fr-2.1.1
kde  kdi-he       OPT   # kde-i18n-he-2.1.1
kde  kdi-hu       OPT   # kde-i18n-hu-2.1.1
kde  kdi-is       OPT   # kde-i18n-is-2.1.1
kde  kdi-it       OPT   # kde-i18n-it-2.1.1
kde  kdi-ja       OPT   # kde-i18n-ja-2.1.1
kde  kdi-ko       OPT   # kde-i18n-ko-2.1.1
kde  kdi-lt       OPT   # kde-i18n-lt-2.1.1
kde  kdi-nl       OPT   # kde-i18n-nl-2.1.1
kde  kdi-no       OPT   # kde-i18n-no-2.1.1
kde  kdi-nony     OPT   # kde-i18n-no_NY-2.1.1
kde  kdi-pl       OPT   # kde-i18n-pl-2.1.1
kde  kdi-pt       OPT   # kde-i18n-pt-2.1.1
kde  kdi-ptbr     OPT   # kde-i18n-pt_BR-2.1.1
kde  kdi-ro       OPT   # kde-i18n-ro-2.1.1
kde  kdi-ru       OPT   # kde-i18n-ru-2.1.1
kde  kdi-sk       OPT   # kde-i18n-sk-2.1.1
kde  kdi-sl       OPT   # kde-i18n-sl-2.1.1
kde  kdi-sr       OPT   # kde-i18n-sr-2.1.1
kde  kdi-sv       OPT   # kde-i18n-sv-2.1.1
kde  kdi-tr       OPT   # kde-i18n-tr-2.1.1
kde  kdi-uk       OPT   # kde-i18n-uk-2.1.1
kde  kdi-zhcn     OPT   # kde-i18n-zh_CN.GB2312-2.1.1
kde  kdi-zhtw     OPT   # kde-i18n-zh_TW.Big5-2.1.1
kde  kdoc         OPT   # kdoc-2.1.1
kde  kgraphic     OPT   # kdegraphics-2.1.1
kde  kmedia       OPT   # kdemultimedia-2.1.1
kde  knetwork     REC   # kdenetwork-2.1.1
kde  koffice      OPT   # koffice-2.0.1
kde  ksupport     ADD   # ksupport-2.1
kde  qt2          ADD   # Qt-2.3.1

n    *            SKP
n    apache       OPT   # Apache WWW server v 1.3.20
n    autofs       OPT   # autofs-3.1.7
n    bind         REC   # bind-9.1.2
n    bitchx       OPT   # BitchX-1.0c18
n    bootp        OPT   # bootp-DD2.4.3
n    dhcp         OPT   # dhcp-2.0pl5, dhcpcd-1.3.20-pl0
n    dip          OPT   # DIP - dialup IP connection handler 3.3.7p
n    elm          OPT   # Menu-driven user mail program. (v. 2.5.3)
n    epic4        OPT   # epic4-1.0.1
n    ftchmail     OPT   # fetchmail-5.8.6
n    imapd        OPT   # imapd (IMAP4rev1 2000.287 from pine4.33)
n    inn          OPT   # inn-2.3.2
n    ipchains     ADD   # ipchains-1.3.10, ipmasqadm-0.4.2
n    iptables     ADD   # iptables-1.2.2
n    lynx         OPT   # Lynx 2.8.3rel.1
n    mailx        REC   # BSD mailx 8.1.1-10
n    metamail     REC   # metamail-2.7
n    mod_php      OPT   # php-4.0.5
n    mod_ssl      OPT   # mod_ssl-2.8.4-1.3.20
n    mutt         OPT   # mutt-1.2.5i
n    ncftp        OPT   # ncftp-2.4.3, ncftp-3.0.2
n    netatalk     OPT   # netatalk-1.4b2+asun2.1.3
n    netpipes     OPT   # netpipes 4.2
n    netwatch     OPT   # netwatch-0.9g
n    nn_nntp      OPT   # nn-6.5.1 compiled to use NNTP.
n    ntp4         OPT   # ntp-4.0.99k23
n    openssh      REC   # openssh-2.9p1
n    openssl      REC   # openssl-0.9.6a
n    pine         OPT   # Pine version 4.33
n    ppp          OPT   # PPP for Linux, version 2.4.1
n    procmail     OPT   # The procmail mail processing program. (v3.15.1 2001/01/08)
n    proftpd      REC   # proftpd-1.2.2rc3
n    rdist        OPT   # rdist-6.1.4.
n    rsync        OPT   # rsync-2.4.6
n    samba        OPT   # Samba 2.2.0a
n    sendmail     REC   # sendmail 8.11.4.
n    smailcfg     OPT   # Configuration files for sendmail.
n    tcpdump      REC   # tcpdump-3.6.1
n    tcpip1       REC   # TCP/IP networking programs and support files.
n    tin          OPT   # tin-1.5.8
n    trn          OPT   # A threaded news reader for reading a remote NNTP server. (v. 3.5)
n    uucp         OPT   # Taylor UUCP version 1.06.2
n    wget         OPT   # wget-1.7
n    yptools      OPT   # NIS servers and clients
n    ytalk        OPT   # ytalk-3.1.1

t    *            SKP
t    tetex        ADD   # teTeX-1.0.7 base support files.
t    tex_bin      ADD   # teTeX-1.0.7 binaries.
t    tex_doc      REC   # Documentation for teTeX-1.0.7.
t    transfig     OPT   # transfig 3.2.3c.
t    xfig         OPT   # xfig 3.2.3c.

tcl  *            SKP
tcl  expect       OPT   # expect-5.32.1.
tcl  hfsutils     OPT   # hfsutils-3.2.6.
tcl  tcl          ADD   # The Tcl script language, version 8.3.3.
tcl  tclx         REC   # Extended Tcl (TclX) 8.3.0.
tcl  tix          OPT   # Tix4.1.0.006.
tcl  tk           REC   # The Tk toolkit for Tcl, version 8.3.3.

x    *            SKP
x    lesstif      OPT   # LessTif 0.92.32
x    xaw3d        ADD   # Xaw3d-1.4
x    xf86doc      REC   # Text documentation for XFree86 4.1.0.
x    xf86html     OPT   # HTML documentation for XFree86 4.1.0.
x    xf86prog     ADD   # Libraries, include files, and configuration files for X programming.
x    xfnts        ADD   # Fonts for the X Window System.
x    xfnts100     OPT   # 100dpi screen fonts for the X Window System.
x    xfntscal     ADD   # Scalable screen fonts for the X Window System.
x    xfntscyr     OPT   # Cyrillic fonts for the X Window System.
x    xfntslt2     OPT   # Latin-2 fonts for the X Window System.
x    xfree86      ADD   # XFree86 4.1.0.
x    xnest        OPT   # Xnest - a nested X server.
x    xprt         OPT   # A Print-only X server (Xprt) for XFree86 4.1.0.
x    xvfb         OPT   # Virtual framebuffer X server.

xap  *            SKP
xap  freefont     REC   # freefonts-0.10
xap  fvwm2        REC   # fvwm-2.2.5
xap  fvwm95       REC   # fvwm95-2.0.43ba-15
xap  fvwmicns     REC   # xpm3icons
xap  gnuchess     REC   # gnuchess-4.0.pl80 and xboard-4.0.2
xap  gnuplot      OPT   # gnuplot 3.7.1
xap  gs_x11       REC   # Replacement /usr/bin/gs with X11 options compiled in.
xap  gv           REC   # gv 3.5.8
xap  imagick      REC   # ImageMagick-5.3.5
xap  netscape     REC   # Netscape Communicator 4.77 (communicator-v477.x86-unknown-linux2.2)
xap  rxvt         REC   # rxvt-2.6.3
xap  seyon        OPT   # Seyon 2.20c.
xap  x3270        OPT   # x3270-3.1.1.9 - IBM host access tool.
xap  xfm          OPT   # xfm 1.3.2, a file manager for X.
xap  xfract       REC   # xfractint-3.10
xap  xgames       REC   # xgames collection
xap  xlock        REC   # xlockmore-5.00
xap  xpaint       OPT   # XPaint 2.4.9.
xap  xpdf         OPT   # xpdf-0.92
xap  xspread      OPT   # xspread-2.3
xap  xv           REC   # John Bradley's XV 3.10a GIF/TIFF/JPEG/PostScript image viewer.
xap  xvim         REC
xap  xxgdb        REC   # xxgdb-1.12.

xv   *            SKP
xv   sspkg        OPT   # SlingShot extensions 2.1
xv   workman      OPT   # WorkMan-1.3a
xv   xv32_a       OPT   # Static libraries for xview3.2p1-X11R6.LinuxELF.4
xv   xv32exmp     OPT   # Sample code for XView
xv   xvinc32      OPT   # Include files for xview3.2p1-X11R6.LinuxELF.4
xv   xvol32       ADD   # Binaries for xview3.2p1-X11R6.LinuxELF.4

y    *            SKP
y    bsdgames     OPT   # BSD games collection, version 2.11.
y    koules       OPT
y    lizards      OPT
y    sastroid     OPT
