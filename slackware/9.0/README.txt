
Welcome to Slackware 9.0!

Slackware 9.0 is a complete distribution of the Linux operating system.

This version contains the 2.4.20 Linux kernel, plus recent versions of these
(and many more) software packages:

- C compiler             gcc-3.2.2
- Binutils               2.13.90.0.18
- GNU C Library          glibc-2.3.1
- X Window System        XFree86 4.3.0
- KDE                    3.1
- GNOME                  2.2

For installation instructions, see the file 'Slackware-HOWTO'.

These are some of the important files and directories found on the Slackware
FTP site:

   ftp://ftp.slackware.com/pub/slackware/slackware-9.0/

If you're reading this on a CD-ROM, these directories will probably be
split across several discs.

.
|-- BOOTING.TXT          Tips for troubleshooting boot problems.
|-- CHECKSUMS.md5        MD5 format file checksums.
|-- COPYING              The GNU Public License.
|-- COPYRIGHT.TXT        Slackware copyright and trademark information.
|-- CRYPTO_NOTICE.TXT    Legal information about encryption in Slackware.
|-- ChangeLog.txt        Log of system changes from Slackware 8.1 to 9.0.
|-- FAQ.TXT              Frequently asked questions and answers.
|-- FILELIST.TXT         List of files on the Slackware FTP site.
|-- GPG-KEY              The GnuPG key used to verify Slackware packages.
|-- PACKAGES.TXT         A detailed list of the core Slackware packages.
|-- SPEAKUP_DOCS.TXT     Documentation for the Speakup speech synth software.
|-- SPEAK_INSTALL.TXT    How to install with Speakup speech synthesis.
|
|-- Slackware-HOWTO      Instructions for installing Slackware from CD.
|                        If you're new to Slackware, start with this.
|
|-- UPGRADE.TXT          Instructions for upgrading from earlier versions.
|
|-- bootdisks/           Bootdisks for installing without a bootable CD-ROM or
|   |                    for starting a Linux system from floppy disk.  See
|   |                    also the rootdisks/ directory below.
|   |
|   |-- RAWRITE.EXE      The "RAWRITE" programs are used to write a floppy
|   |-- RAWRITE12.DOC    image under DOS or Windows.  Because there are a lot
|   |-- RAWRITE12.EXE    of versions of DOS and Windows, there are several
|   |-- RAWRITENT.DOC    versions of RAWRITE, and you may have to try a few
|   |-- RAWRITENT.EXE    before finding one that works with your version of DOS
|   |-- RAWRITEXP.EXE    or Windows.
|   | 
|   |-- README.TXT       Detailed descriptions of all the boot floppies.
|   |
|   |-- adaptec.s        Adaptec bootdisk.
|   |-- ataraid.s        Bootdisk with ATA (IDE) RAID support.
|   |-- bare.i           Standard IDE/ATAPI bootdisk (default kernel).
|   |-- ibmmca.s         IBM PS/2 Microchannel bus bootdisk.
|   |-- jfs.s            Bootdisk with IBM JFS support.
|   |-- lowmem.i         Bootdisk for machines too low on RAM to boot bare.i.
|   |                    This is also the only kernel that supports a 386.
|   |-- old_cd.i         Old non-SCSI non-IDE CD-ROM drive support bootdisk.
|   |-- pportide.i       Parallel port IDE bootdisk.
|   |-- raid.s           SCSI RAID bootdisk.
|   |-- scsi.s           Supports some SCSI cards (see bootdisks/README.TXT).
|   |-- scsi2.s          Supports some SCSI cards (see bootdisks/README.TXT).
|   |-- speakup.i        bare.i + Speakup speech support.
|   `-- xfs.i            Bootdisk with support for SGI XFS.
|
|-- extra/               Extra packages for Slackware like:
|   |                    3dfx-glide libraries, aspell-word-lists, aumix-2.7,
|   |                    bash-completion-20030209, bison-1.875, blackbox-0.65.0,
|   |                    brltty-2.99.8, btmgr-3.7, checkinstall-1.5.3,
|   |                    cups-1.1.18, db-4.1.25, dip-3.3.7p, emacspeak-16.0,
|   |                    emacspeak-ss-1.9.1, emu-tools-0.9.4, fluxbox-0.1.14,
|   |                    gimp-1.3.12, glibc-extra-packages, ham radio packages,
|   |                    iproute2-2.4.7-now-ss020116-try, isdn4k-utils,
|   |                    java2-runtime-environment, kernel-modules-2.4.20_xfs,
|   |                    kfiresaver3d-0.6, libsafe-2.0-16, lilo-22.5,
|   |                    links-2.1pre7, mpg123-0.59r, openmotif-2.2.1,
|   |                    parted-1.6.5, sgml-tools-1.0.9, vlc-0.5.2,
|   |                    xcdroast-0.98alpha13, and xlockmore-5.06.
|   |
|   `-- source/          Source code for the extra packages.
|
|-- isolinux/            The ISOLINUX loader and initrd.img used to install
|   |                    Slackware from a CD-ROM.  You'll also find the
|   |                    PCMCIA and network images (these can be loaded
|   |                    from the installation CD-ROM), and a README.TXT
|   |                    describing how to create a Slackware installation
|   |                    ISO image and burn it to CD-R.
|   |
|   |-- README.TXT       How to burn a Bootable Slackware CD-ROM.
|   |-- initrd.img       Installation initrd (can also be loaded with Loadlin)
|   |-- network.dsk      Image containing network modules.
|   `-- pcmcia.dsk       Image containing PCMCIA modules.
|
|-- kernels/             Many precompiled Linux 2.4.20 kernel images.
|   |
|   |-- adaptec.s/       Adaptec kernel.
|   |-- ataraid.s/       Kernel with ATA (IDE) RAID support.
|   |-- bare.i/          Standard IDE kernel.
|   |-- ibmmca.s/        IBM Microchannel kernel.
|   |-- jfs.s/           IBM Journaled Filesystem +aic7xxx SCSI kernel.
|   |-- loadlin16c.txt   Loadlin README file.
|   |-- loadlin16c.zip   Loadlin boot loader (used to boot Linux from DOS)
|   |-- lowmem.i/        Kernel that uses very little memory.
|   |-- old_cd.i/        Old non-SCSI non-IDE CD-ROM support kernel.
|   |-- pportide.i/      Parallel port IDE kernel.
|   |-- raid.s/          SCSI RAID kernel.
|   |-- scsi.s/          Supports some SCSI cards (see bootdisks/README.TXT).
|   |-- scsi2.s/         Supports some SCSI cards (see bootdisks/README.TXT).
|   |-- speakup.i/       bare.i + Speakup speech support.
|   |-- xfs.i/           Kernel with support for SGI XFS.
|   `-- zipslack.s/      Kernel with Iomega support.
|
|-- pasture/             These are packages that have been removed
|                        from Slackware, but are useful enough to
|                        keep around.  Packages currently found here
|                        include old XFree86-3.3.6-servers,
|                        XFree86-4.2.1.1, db3-3.1.17, freetype-1.3.1,
|                        gnu-pop3d-0.9.8, libglut-3.7, libxml-1.8.17,
|                        pop3d-1.020i, wu-ftpd-2.6.2, and xview-3.2p1.4.
|   
|-- rootdisks/           Slackware installation and rescue floppy images.
|   |
|   |-- RAWRITE.EXE      The "RAWRITE" programs are used to write a floppy
|   |-- RAWRITE12.DOC    image under DOS or Windows.
|   |-- RAWRITE12.EXE
|   |-- RAWRITENT.DOC
|   |-- RAWRITENT.EXE
|   |-- RAWRITEXP.EXE
|   |
|   |-- README.TXT       This README.TXT file explains the various choices.
|   |-- install.1        install.1 and install.2 are the install floppy images.
|   |-- install.2        If you will be starting the install using a boot
|   |                    floppy, then you will need to load both of these.
|   |
|   |-- install.zip          install.zip is a version of the installer that
|   |-- install.zip.README   runs from a DOS partition.  See the README.
|   |
|   |-- network.dsk          This is used also with install.1 and install.2
|   |-- network.dsk.README   to do installation from an NFS server.
|   |
|   |-- pcmcia.dsk           This is used to activate PCMCIA devices (laptop
|   |-- pcmcia.dsk.README    cards) needed during installation.
|   |
|   |-- rescue.dsk           A simple rescue floppy you can load with a
|   |-- rescue.dsk.README    bootdisk.
|   |
|   `-- sbootmgr.dsk         A small image containing a simple boot manager.
|                            In some cases this can be used to boot a CD in a
|                            machine that otherwise couldn't support it.
|
|-- slackware/           This directory contains the core software packages
|   |                    for Slackware 9.0.
|   |
|   |-- a/               The A (base) package series.
|   |-- ap/              The AP (applications) package series.
|   |-- d/               The D (development) package series.
|   |-- e/               The E (GNU Emacs) package series.
|   |-- f/               The F (FAQ/Documentation) package series.
|   |-- gnome/           The GNOME package series.
|   |-- k/               The K (kernel source) package series.
|   |-- kde/             The KDE package series.
|   |-- kdei/            The KDE internationalization package series.
|   |-- l/               The L (libraries) package series.
|   |-- n/               The N (networking) package series.
|   |-- t/               The T (TeX) package series.
|   |-- tcl/             The TCL (Tcl/Tk and related) package series.
|   |-- x/               The X (XFree86) package series.
|   |-- xap/             The XAP (X applications) package series.
|   `-- y/               The Y (BSD games) package series.
|
|-- source/              This directory contains source code for the core
|   |                    software packages in Slackware.
|   |
|   |-- a/               Source for the A (base) series.
|   |-- ap/              Source for the AP (applications) series.
|   |-- d/               Source for the D (development) series.
|   |-- e/               Source for the E (GNU Emacs) series.
|   |-- f/               slack-desc files for the F (FAQ) series.
|   |-- gnome/           Source for the GNOME series.
|   |-- k/               Source for the K (kernel source) series.
|   |-- kde/             Source for the KDE series.
|   |-- kdei/            Source for the KDEI series.
|   |-- l/               Source for the L (libraries) series.
|   |-- n/               Source for the N (networking) series.
|   |-- rootdisks/       Source for utilities on the rootdisks.
|   |-- t/               Source for the T (TeX) series.
|   |-- tcl/             Source for the TCL (Tcl/Tk and related) series.
|   |-- x/               Source for the X (XFree86) series.
|   |-- xap/             Source for the XAP (X applications) series.
|   `-- y/               Source for the Y (BSD games) series.
|
`-- zipslack/            This is ZipSlack, a small (100MB) Slackware
    |                    system packaged as a Zip file.  Installation
    |                    is as simple as unzipping zipslack.zip on a FAT or
    |                    FAT32 partition, or Zip disk.  It does not come
    |                    with X, but is otherwise fairly complete, including
    |                    many networking tools.  The package management tools
    |                    allow you to add as much extra software as you need
    |                    (such as X) once you boot the system.  For more
    |                    information, see the README.1st file.
    |
    |-- ChangeLog.txt    Changes to ZipSlack.
    |-- FAQ.TXT          ZipSlack FAQ.
    |
    |-- RAWRITE.EXE      The "RAWRITE" programs are used to write a floppy
    |-- RAWRITE12.DOC    image under DOS or Windows.
    |-- RAWRITE12.EXE 
    |-- RAWRITENT.DOC
    |-- RAWRITENT.EXE 
    |-- RAWRITEXP.EXE 
    |
    |-- README.1st       ZipSlack README and installation instructions.
    |-- README.ppa       Information about parallel port Zip drives.
    |-- bootdisk.img     A bootdisk you can use to boot ZipSlack.
    |-- fourmeg.txt      README for the 8MB swapfile package for ZipSlack.
    |-- fourmeg.zip      An 8MB swapfile useful on machines with low RAM.
    |-- split/           ZipSlack split into floppy-sized chunks.
    `-- zipslack.zip     ZipSlack as a single Zip archive.


If you like Slackware, please consider supporting the project by becoming
a Slackware subscriber.  The announcement (ANNOUNCE_9.0) in this directory
has information about subscribing to the Slackware CD-ROM releases, or you
can read about it (and check out other Slackware products) by visiting the
Slackware store:

    http://store.slackware.com


Enjoy!

Patrick Volkerding
volkerdi@slackware.com

