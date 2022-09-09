#!/usr/bin/env bash
# Runs qemu using files in the current or specified directory
SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPTDIR/common.sh

if [[ $# -lt 1 ]]; then
  echo "Usage $(basename $0) conf"
  exit 1
fi

$SCRIPTDIR/extract.sh $1

CONF=$PWD/$1
CACHE=$CACHEBASE/$1
QEMUDIR=$QEMUBASE/$1
mkdir -p $QEMUDIR
cd $QEMUDIR
shift

# Prepare to run
if [[ -f $CONF/prep.sh ]]; then
  source $CONF/prep.sh
fi

QEMU="qemu-system-i386"
QEMU_MACHINE="type=isapc"
QEMU_SMP="1"
QEMU_RAM="16M"
QEMU_NET="ne2k_isa"
QEMU_EXTRA=""

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
      FORMAT=qcow2
    else
      FORMAT=raw
    fi
  fi
  if [[ -f $DRIVE.img ]]; then
    QEMU_DRIVES="$QEMU_DRIVES -drive if=$INTERFACE,index=$INDEX,format=$FORMAT,file=$DRIVE.img"
  elif [[ -f $DRIVE.iso ]]; then
    QEMU_DRIVES="$QEMU_DRIVES -drive if=$INTERFACE,index=$INDEX,format=$FORMAT,file=$DRIVE.iso"
  elif [[ -d $DRIVE ]]; then
    QEMU_DRIVES="$QEMU_DRIVES -drive if=$INTERFACE,index=$INDEX,format=raw,file=fat:rw:$DRIVE"
  fi
done

# Run QEMU
$QEMU \
  -machine $QEMU_MACHINE \
  -smp $QEMU_SMP \
  -m $QEMU_RAM \
  -netdev socket,id=retronet,connect=:1234 \
  -device $QEMU_NET,netdev=retronet \
  -serial mon:stdio \
  $QEMU_DRIVES \
  $QEMU_EXTRA \
  $@
