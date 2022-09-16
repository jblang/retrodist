#!/usr/bin/env bash
# Runs qemu configured for the specified distro
SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPTDIR/common.sh

if [[ $# -lt 1 ]]; then
  echo "Usage $(basename $0) conf"
  exit 1
fi
NAME=$1
shift

# automatically download and extract
$SCRIPTDIR/extract.sh $NAME

# for distros that are sourced from elsewhere
CONFDIR=$PWD/$NAME
if [[ -f $CONFDIR/source.txt ]]; then
  SOURCE=$(cat $CONFDIR/source.txt)
  ORIGDIR=$ORIGBASE/$SOURCE
else
  ORIGDIR=$ORIGBASE/$NAME
fi
CACHEDIR=$CACHEBASE/$NAME
QEMUDIR=$QEMUBASE/$NAME
mkdir -p $QEMUDIR
cd $QEMUDIR

# link installation files
if [[ -f $CACHEDIR/boot.img && ! -f fda.img ]]; then
  ln -s $CACHEDIR/boot.img fda.img
fi
if [[ -f $CACHEDIR/root.img && ! -f fdb.img ]]; then
  ln -s $CACHEDIR/root.img fdb.img
fi
if [[ -f $ORIGDIR/disc1.iso && ! -f hdc.iso ]]; then
  ln -s $ORIGDIR/disc1.iso hdc.iso
fi
if [[ -d $CACHEDIR/install && ! -d hdb ]]; then
  ln -s $CACHEDIR/install hdb
fi

# default configuration
QEMU_SYSTEM="qemu-system-i386"
QEMU_MACHINE="type=isapc"
QEMU_SMP="1"
QEMU_RAM="16M"
QEMU_HD_SIZE="500M"
QEMU_HD_FORMAT="qcow2"
QEMU_NET_DEVICE="ne2k_isa"
QEMU_INTERNET="" # disabled
QEMU_RETRONET="
  -netdev socket,id=retronet,connect=:1234
  -device $QEMU_NET_DEVICE,netdev=retronet"
QEMU_EXTRA=""

# Allow overriding default configuration
if [[ -f $CONFDIR/qemu.sh ]]; then
  source $CONFDIR/qemu.sh
fi

# create hard drive image
if [[ ! -f hda.img ]]; then
  qemu-img create -f $QEMU_HD_FORMAT hda.img $QEMU_HD_SIZE
fi

# Add -drive parameters for each image provided
QEMU_DRIVES=""
for DRIVE in fda fdb hda hdb hdc hdd; do
  INDEX=$(echo $DRIVE | cut -c3 | tr abcd 0123)
  if [[ $DRIVE = fd* ]]; then
    INTERFACE=floppy
    FORMAT=raw
  else
    INTERFACE=ide
    if [[ -f $DRIVE.img ]]; then
      FORMAT=$QEMU_HD_FORMAT
    else
      FORMAT=raw
    fi
  fi
  if [[ -f $DRIVE.img ]]; then
    QEMU_DRIVES="$QEMU_DRIVES -drive if=$INTERFACE,index=$INDEX,format=$FORMAT,file=$DRIVE.img"
  elif [[ -f $DRIVE.iso ]]; then
    QEMU_DRIVES="$QEMU_DRIVES -drive if=$INTERFACE,index=$INDEX,format=$FORMAT,media=cdrom,file=$DRIVE.iso"
  elif [[ -d $DRIVE ]]; then
    QEMU_DRIVES="$QEMU_DRIVES -drive if=$INTERFACE,index=$INDEX,format=raw,file=fat:rw:$DRIVE"
  fi
done

set | grep QEMU_

# Run QEMU
$QEMU_SYSTEM \
  -machine $QEMU_MACHINE \
  -smp $QEMU_SMP \
  -m $QEMU_RAM \
  -serial mon:stdio \
  $QEMU_INTERNET \
  $QEMU_RETRONET \
  $QEMU_DRIVES \
  $QEMU_EXTRA \
  $@
