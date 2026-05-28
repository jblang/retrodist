# shellcheck shell=bash
# QEMU configuration, boot, packaging, prerequisite install, and reset helpers.
qemu_default_display() {
  case "$(uname -s)" in
    Darwin)
      echo "-display cocoa,zoom-to-fit=on,zoom-interpolation=on"
      ;;
    *)
      echo "-display gtk"
      ;;
  esac
}

qemu_warn_missing_display_backend() {
  local backend available
  if [[ -z "$QEMU_DISPLAY" || "$QEMU_DISPLAY" != *"-display "* ]]; then
    return
  fi

  backend=${QEMU_DISPLAY#*-display }
  backend=${backend%%[ ,]*}
  backend=${backend%%=*}
  if [[ -z "$backend" || "$backend" == "none" ]]; then
    return
  fi

  available=$($QEMU_SYSTEM -display help 2>/dev/null || true)
  if [[ -n "$available" && "$available" != *"$backend"* ]]; then
    echo "Warning: $QEMU_SYSTEM does not have the '$backend' display backend installed."
    echo "Install a QEMU UI backend package, or set QEMU_DISPLAY to another backend."
    echo
  fi
}

qemu_append_shell_words() {
  if [[ -n "${1:-}" ]]; then
    eval "QEMU_ARGS+=( $1 )"
  fi
}

qemu_render_command_sh() {
  local rendered=
  printf -v rendered '%q ' "${QEMU_ARGS[@]}"
  printf '%s\n' "${rendered% }"
}

qemu_render_command_cmd() {
  local arg
  local rendered=
  for arg in "${QEMU_ARGS[@]}"; do
    case "$arg" in
      *[[:space:]\"]*)
        arg=${arg//\"/\"\"}
        rendered="$rendered \"$arg\""
        ;;
      *)
        rendered="$rendered $arg"
        ;;
    esac
  done
  printf '%s\n' "${rendered# }"
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
  local qemu_profile_env_decl qemu_profile_env=
  local qemu_profile_env_set=
  qemu_profile_env_decl=$(declare -p QEMU_PROFILE 2>/dev/null || true)
  if [[ $qemu_profile_env_decl == declare\ -*x* ]]; then
    qemu_profile_env=$QEMU_PROFILE
    qemu_profile_env_set=1
  fi

  qemu_base_defaults
  if [[ -f $CONFDIR/qemu.sh ]]; then
    # shellcheck source=/dev/null
    source "$CONFDIR/qemu.sh"
  fi
  if [[ -n "$qemu_profile_env_set" ]]; then
    QEMU_PROFILE=$qemu_profile_env
  fi
  qemu_apply_profile
  qemu_finish_config
}

load_distro_config() {
  if [[ -f $CONFDIR/config.sh ]]; then
    # shellcheck source=/dev/null
    source "$CONFDIR/config.sh"
  fi
}

qemu_link_boot_media() {
  if [[ -f $EXTRACTDIR/boot.img && ! -e boot.img ]]; then
    ln -s "$EXTRACTDIR/boot.img" boot.img
  fi
  if [[ -f $EXTRACTDIR/root.img && ! -e root.img ]]; then
    ln -s "$EXTRACTDIR/root.img" root.img
  fi
  if [[ -f $EXTRACTDIR/boot.img && ! -f fda.img ]]; then
    ln -s "$EXTRACTDIR/boot.img" fda.img
  fi
  if [[ -f $EXTRACTDIR/root.img && $QEMU_ATTACH_ROOT_FDB == "1" && ! -f fdb.img ]]; then
    ln -s "$EXTRACTDIR/root.img" fdb.img
  fi
  if [[ -n "${QEMU_CDROM:-}" && -f "$ORIGDIR/$QEMU_CDROM" && ! -f hdc.iso ]]; then
    ln -s "$ORIGDIR/$QEMU_CDROM" hdc.iso
  elif [[ -f $ORIGDIR/disc1.iso && ! -f hdc.iso ]]; then
    ln -s "$ORIGDIR/disc1.iso" hdc.iso
  fi
  if [[ -d $EXTRACTDIR/install && ! -d hdb ]]; then
    ln -s "$EXTRACTDIR/install" hdb
  fi
}

qemu_ensure_primary_disk() {
  local create_options
  if [[ ! -f hda.img ]]; then
    if [[ -f fda.img || -f hdc.iso ]]; then
      create_options=()
      if [[ -n "${QEMU_HD_CREATE_OPTIONS:-}" ]]; then
        create_options=(-o "$QEMU_HD_CREATE_OPTIONS")
      fi
      qemu-img create -f "$QEMU_HD_FORMAT" "${create_options[@]}" hda.img "$QEMU_HD_SIZE"
    else
      return 1
    fi
  fi
}

qemu_drive_index() {
  case "$1" in
    hda | fda) echo 0 ;;
    hdb | fdb) echo 1 ;;
    hdc) echo 2 ;;
    hdd) echo 3 ;;
  esac
}

qemu_build_drives() {
  local drive index interface format drive_options
  QEMU_DRIVES=()
  for drive in fda fdb hda hdb hdc hdd; do
    index=$(qemu_drive_index "$drive")
    if [[ $drive = fd* ]]; then
      interface=floppy
      format=raw
    else
      interface=ide
      if [[ -f $drive.img ]]; then
        format=$QEMU_HD_FORMAT
      else
        format=raw
      fi
    fi
    drive_options=""
    if [[ $drive == "hda" && -n "${QEMU_HDA_OPTIONS:-}" ]]; then
      drive_options=",$QEMU_HDA_OPTIONS"
    fi
    if [[ -f $drive.img ]]; then
      QEMU_DRIVES+=(-drive "if=$interface,index=$index,format=$format,file=$drive.img$drive_options")
    elif [[ -f $drive.iso ]]; then
      QEMU_DRIVES+=(-drive "if=$interface,index=$index,format=$format,media=cdrom,file=$drive.iso")
    elif [[ -d $drive ]]; then
      QEMU_DRIVES+=(-drive "if=$interface,index=$index,format=raw,file=fat:rw:$drive")
    fi
  done
}

qemu_build_globals() {
  QEMU_GLOBALS=()
  if [[ -n "$QEMU_FDTYPE_A" ]]; then
    QEMU_GLOBALS+=(-global "isa-fdc.fdtypeA=$QEMU_FDTYPE_A")
  fi
  if [[ -n "$QEMU_FDTYPE_B" ]]; then
    QEMU_GLOBALS+=(-global "isa-fdc.fdtypeB=$QEMU_FDTYPE_B")
  fi
}

qemu_build_args() {
  QEMU_ARGS=(
    "$QEMU_SYSTEM"
    -machine "$QEMU_MACHINE"
    -smp "$QEMU_SMP"
    -m "$QEMU_RAM"
    -serial mon:stdio
  )
  qemu_append_shell_words "${QEMU_DISPLAY:-}"
  qemu_append_shell_words "${QEMU_ACCEL:-}"
  qemu_append_shell_words "${QEMU_INTERNET:-}"
  qemu_append_shell_words "${QEMU_RETRONET:-}"
  QEMU_ARGS+=("${QEMU_GLOBALS[@]}")
  QEMU_ARGS+=("${QEMU_DRIVES[@]}")
  qemu_append_shell_words "${QEMU_BOOT_ORDER:-}"
  qemu_append_shell_words "${QEMU_EXTRA:-}"
  QEMU_ARGS+=("$@")
  QEMU_COMMAND=$(qemu_render_command_sh)
}

qemu_cleanup_empty_dir() {
  if [[ -d $QEMUDIR && -z $(ls -A "$QEMUDIR") ]]; then
    rmdir "$QEMUDIR"
  fi
}

retro_boot() {
  retro_extract
  mkdir -p "$QEMUDIR"

  load_distro_config
  load_qemu_config

  pushd "$QEMUDIR" > /dev/null || return

  qemu_link_boot_media
  if ! qemu_ensure_primary_disk; then
    echo "No bootable devices"
    popd > /dev/null || return
    qemu_cleanup_empty_dir
    exit 1
  fi

  qemu_build_drives
  qemu_build_globals
  qemu_warn_missing_display_backend

  qemu_build_args "$@"

  echo
  echo "QEMU command: $QEMU_COMMAND"
  echo
  if [[ $COMMAND == "boot" || $COMMAND == "install" ]]; then
    "${QEMU_ARGS[@]}"
  fi
  popd > /dev/null || return
}

retro_package() {
  local files tarname package_root package_dir item
  if [[ $# -ge 1 && $1 == "--hda" ]]; then
    files=(hda.img retro.bat retro.sh)
    shift
  else
    files=()
  fi
  retro_boot "$@"
  echo
  echo "Packaging $CONFNAME..."
  {
    printf '@echo off\n'
    qemu_render_command_cmd
  } > "$QEMUDIR/retro.bat"
  {
    printf '#!/bin/sh\n'
    printf '%s\n' "$QEMU_COMMAND"
  } > "$QEMUDIR/retro.sh"
  chmod +x "$QEMUDIR/retro.sh"
  tarname=$(printf '%s\n' "$CONFNAME" | tr / -)
  package_root=$TEMPDIR/package
  package_dir=$package_root/$tarname
  rm -rf "$package_root"
  mkdir -p "$package_dir"
  if [[ ${#files[@]} -eq 0 ]]; then
    for item in "$QEMUDIR"/*; do
      [[ -e "$item" ]] || continue
      cp -RL "$item" "$package_dir/"
    done
  else
    for item in "${files[@]}"; do
      [[ -e "$QEMUDIR/$item" ]] || continue
      cp -RL "$QEMUDIR/$item" "$package_dir/"
    done
  fi
  tar -C "$package_root" -czhf "$tarname.tar.gz" "$tarname"
  ls -lh "$tarname.tar.gz"
}

retro_reset() {
  read -p "Really remove QEMU images and extracted files for $CONFNAME? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    rm -rf "$EXTRACTDIR"
    rm -rf "$QEMUDIR"
    echo "Distro reset."
  else
    echo "Reset aborted."
  fi
}
