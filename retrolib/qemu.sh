# QEMU configuration, boot, packaging, prerequisite install, and reset helpers.
qemu_default_display() {
  case "$(uname -s)" in
    Darwin)
      echo "-display cocoa"
      ;;
    *)
      echo "-display gtk"
      ;;
  esac
}

qemu_warn_missing_display_backend() {
  if [[ -z "$QEMU_DISPLAY" || "$QEMU_DISPLAY" != *"-display "* ]]; then
    return
  fi

  local BACKEND=${QEMU_DISPLAY#*-display }
  BACKEND=${BACKEND%%[ ,]*}
  BACKEND=${BACKEND%%=*}
  if [[ -z "$BACKEND" || "$BACKEND" == "none" ]]; then
    return
  fi

  local AVAILABLE
  AVAILABLE=$($QEMU_SYSTEM -display help 2>/dev/null || true)
  if [[ -n "$AVAILABLE" && "$AVAILABLE" != *"$BACKEND"* ]]; then
    echo "Warning: $QEMU_SYSTEM does not have the '$BACKEND' display backend installed."
    echo "Install a QEMU UI backend package, or set QEMU_DISPLAY to another backend."
    echo
  fi
}

qemu_base_defaults() {
  QEMU_SYSTEM="${QEMU_SYSTEM:-qemu-system-i386}"
  QEMU_PROFILE="${QEMU_PROFILE:-default}"
  QEMU_SMP="${QEMU_SMP:-1}"
  QEMU_HD_FORMAT="${QEMU_HD_FORMAT:-qcow2}"
  QEMU_HD_CREATE_OPTIONS="${QEMU_HD_CREATE_OPTIONS:-}"
  QEMU_HDA_OPTIONS="${QEMU_HDA_OPTIONS:-}"
  QEMU_CDROM="${QEMU_CDROM:-disc1.iso}"
  QEMU_ATTACH_ROOT_FDB="${QEMU_ATTACH_ROOT_FDB:-0}"
  QEMU_FDTYPE_A="${QEMU_FDTYPE_A:-144}"
  QEMU_FDTYPE_B="${QEMU_FDTYPE_B:-144}"
  QEMU_INTERNET="${QEMU_INTERNET:-}"
  QEMU_BOOT_ORDER="${QEMU_BOOT_ORDER:-}"
  QEMU_RETRONET="${QEMU_RETRONET:-}"
}

qemu_apply_profile() {
  QEMU_PROFILE=${1:-${QEMU_PROFILE:-default}}
  case $QEMU_PROFILE in
    default)
      QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
      QEMU_RAM="${QEMU_RAM:-16M}"
      QEMU_HD_SIZE="${QEMU_HD_SIZE:-500M}"
      QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
      ;;
    linux-0.99)
      QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
      QEMU_RAM="${QEMU_RAM:-16M}"
      QEMU_HD_SIZE="${QEMU_HD_SIZE:-500M}"
      QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
      ;;
    linux-1.0)
      QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
      QEMU_RAM="${QEMU_RAM:-64M}"
      QEMU_HD_SIZE="${QEMU_HD_SIZE:-500M}"
      QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
      ;;
    linux-1.2)
      QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
      QEMU_RAM="${QEMU_RAM:-64M}"
      QEMU_HD_SIZE="${QEMU_HD_SIZE:-2G}"
      QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
      QEMU_ACCEL="${QEMU_ACCEL:--accel tcg}"
      ;;
    linux-2.0-isa)
      QEMU_MACHINE="${QEMU_MACHINE:-type=isapc}"
      QEMU_RAM="${QEMU_RAM:-64M}"
      QEMU_HD_SIZE="${QEMU_HD_SIZE:-2G}"
      QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_isa}"
      ;;
    linux-2.0)
      QEMU_MACHINE="${QEMU_MACHINE:-type=pc}"
      QEMU_RAM="${QEMU_RAM:-64M}"
      QEMU_HD_SIZE="${QEMU_HD_SIZE:-2G}"
      QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_pci}"
      QEMU_EXTRA="${QEMU_EXTRA:--vga cirrus}"
      ;;
    linux-2.2)
      QEMU_MACHINE="${QEMU_MACHINE:-type=pc}"
      QEMU_RAM="${QEMU_RAM:-64M}"
      QEMU_HD_SIZE="${QEMU_HD_SIZE:-2G}"
      QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_pci}"
      QEMU_EXTRA="${QEMU_EXTRA:--vga cirrus}"
      ;;
    linux-2.4)
      QEMU_MACHINE="${QEMU_MACHINE:-type=pc}"
      QEMU_RAM="${QEMU_RAM:-128M}"
      QEMU_HD_SIZE="${QEMU_HD_SIZE:-8G}"
      QEMU_NET_DEVICE="${QEMU_NET_DEVICE:-ne2k_pci}"
      QEMU_EXTRA="${QEMU_EXTRA:--vga std}"
      ;;
    *)
      echo "Unknown QEMU_PROFILE '$QEMU_PROFILE'"
      exit 1
      ;;
  esac
}

qemu_finish_config() {
  QEMU_DISPLAY="${QEMU_DISPLAY:-$(qemu_default_display)}"
  QEMU_ACCEL="${QEMU_ACCEL:--accel tcg}"
  QEMU_EXTRA="${QEMU_EXTRA:-}"
  if [[ $COMMAND == "install" ]]; then
    if [[ -f "$QEMUDIR/fda.img" ]]; then
      QEMU_BOOT_ORDER="-boot order=a"
    else
      QEMU_BOOT_ORDER="-boot order=d"
    fi
  fi
  if [[ -z "${QEMU_RETRONET:-}" && -n "${QEMU_NET_DEVICE:-}" ]]; then
    QEMU_RETRONET="
      -netdev socket,id=retronet,connect=:1234
      -device $QEMU_NET_DEVICE,netdev=retronet"
  fi
}

load_qemu_config() {
  local QEMU_PROFILE_ENV_DECL QEMU_PROFILE_ENV
  QEMU_PROFILE_ENV_DECL=$(declare -p QEMU_PROFILE 2>/dev/null || true)
  if [[ $QEMU_PROFILE_ENV_DECL == declare\ -*x* ]]; then
    QEMU_PROFILE_ENV=$QEMU_PROFILE
  fi

  qemu_base_defaults
  if [[ -f $CONFDIR/qemu.sh ]]; then
    source $CONFDIR/qemu.sh
  fi
  if [[ ${QEMU_PROFILE_ENV+x} ]]; then
    QEMU_PROFILE=$QEMU_PROFILE_ENV
  fi
  qemu_apply_profile
  qemu_finish_config
}

load_distro_config() {
  if [[ -f $CONFDIR/config.sh ]]; then
    source $CONFDIR/config.sh
  fi
}

retro_boot() {
  retro_extract
  mkdir -p $QEMUDIR

  load_distro_config
  load_qemu_config

  pushd $QEMUDIR > /dev/null

  if [[ -f $EXTRACTDIR/boot.img && ! -e boot.img ]]; then
    ln -s $EXTRACTDIR/boot.img boot.img
  fi
  if [[ -f $EXTRACTDIR/root.img && ! -e root.img ]]; then
    ln -s $EXTRACTDIR/root.img root.img
  fi
  if [[ -f $EXTRACTDIR/boot.img && ! -f fda.img ]]; then
    ln -s $EXTRACTDIR/boot.img fda.img
  fi
  if [[ -f $EXTRACTDIR/root.img && $QEMU_ATTACH_ROOT_FDB == "1" && ! -f fdb.img ]]; then
    ln -s $EXTRACTDIR/root.img fdb.img
  fi
  if [[ -n "${QEMU_CDROM:-}" && -f "$ORIGDIR/$QEMU_CDROM" && ! -f hdc.iso ]]; then
    ln -s "$ORIGDIR/$QEMU_CDROM" hdc.iso
  elif [[ -f $ORIGDIR/disc1.iso && ! -f hdc.iso ]]; then
    ln -s $ORIGDIR/disc1.iso hdc.iso
  fi
  if [[ -d $EXTRACTDIR/install && ! -d hdb ]]; then
    ln -s $EXTRACTDIR/install hdb
  fi

  if [[ ! -f hda.img ]]; then
    if [[ -f fda.img || -f hdc.iso ]]; then
      CREATE_OPTIONS=()
      if [[ -n "${QEMU_HD_CREATE_OPTIONS:-}" ]]; then
        CREATE_OPTIONS=(-o "$QEMU_HD_CREATE_OPTIONS")
      fi
      qemu-img create -f "$QEMU_HD_FORMAT" "${CREATE_OPTIONS[@]}" hda.img "$QEMU_HD_SIZE"
    else
      echo "No bootable devices"
      if [[ -d $QEMUDIR && -z $(ls -A $QEMUDIR) ]]; then
        rmdir $QEMUDIR
      fi
      exit 1
    fi
  fi

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
    DRIVE_OPTIONS=""
    if [[ $DRIVE == "hda" && -n "${QEMU_HDA_OPTIONS:-}" ]]; then
      DRIVE_OPTIONS=",$QEMU_HDA_OPTIONS"
    fi
    if [[ -f $DRIVE.img ]]; then
      QEMU_DRIVES="$QEMU_DRIVES -drive if=$INTERFACE,index=$INDEX,format=$FORMAT,file=$DRIVE.img$DRIVE_OPTIONS"
    elif [[ -f $DRIVE.iso ]]; then
      QEMU_DRIVES="$QEMU_DRIVES -drive if=$INTERFACE,index=$INDEX,format=$FORMAT,media=cdrom,file=$DRIVE.iso"
    elif [[ -d $DRIVE ]]; then
      QEMU_DRIVES="$QEMU_DRIVES -drive if=$INTERFACE,index=$INDEX,format=raw,file=fat:rw:$DRIVE"
    fi
  done

  QEMU_GLOBALS=""
  if [[ -n "$QEMU_FDTYPE_A" ]]; then
    QEMU_GLOBALS="$QEMU_GLOBALS -global isa-fdc.fdtypeA=$QEMU_FDTYPE_A"
  fi
  if [[ -n "$QEMU_FDTYPE_B" ]]; then
    QEMU_GLOBALS="$QEMU_GLOBALS -global isa-fdc.fdtypeB=$QEMU_FDTYPE_B"
  fi
  qemu_warn_missing_display_backend

  QEMU_COMMAND="
    $QEMU_SYSTEM
      -machine $QEMU_MACHINE
      -smp $QEMU_SMP
      -m $QEMU_RAM
      -serial mon:stdio
      $QEMU_DISPLAY
      $QEMU_ACCEL
      $QEMU_INTERNET
      $QEMU_RETRONET
      $QEMU_GLOBALS
      $QEMU_DRIVES
      $QEMU_BOOT_ORDER
      $QEMU_EXTRA
      $@"

  QEMU_COMMAND=$(echo $QEMU_COMMAND | tr -d '\n' | tr -s ' ')
  echo
  echo "QEMU command: $QEMU_COMMAND"
  echo
  if [[ $COMMAND == "boot" || $COMMAND == "install" ]]; then
    $QEMU_COMMAND
  fi
  popd > /dev/null
}

retro_package() {
  echo $@
  if [[ $# -ge 1 && $1 == "--hda" ]]; then
    FILES="hda.img retro.bat retro.sh"
    shift
  else
    FILES="*"
  fi
  retro_boot $@
  echo
  echo "Packaging $CONFNAME..."
  echo "@echo off" > "$QEMUDIR/retro.bat"
  echo $QEMU_COMMAND >> "$QEMUDIR/retro.bat"
  echo "#!/bin/sh" > "$QEMUDIR/retro.sh"
  echo $QEMU_COMMAND >> "$QEMUDIR/retro.sh"
  chmod +x "$QEMUDIR/retro.sh"
  TARNAME=$(echo $CONFNAME | tr / -)
  (cd $QEMUDIR; tar cvfz ../$TARNAME.tar.gz $FILES --dereference --transform "s|^|$TARNAME/|")
  ls -lh $TARNAME.tar.gz
}

retro_reset() {
  read -p "Really remove QEMU images and extracted files for $CONFNAME? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf $EXTRACTDIR
    rm -rf $QEMUDIR
    echo "Distro reset."
  else
    echo "Reset aborted."
  fi
}
