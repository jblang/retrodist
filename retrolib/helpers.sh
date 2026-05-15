# Shared shell helpers used across download, extract, autoinstall, and QEMU code.
cat_newline() {
  cat $1
  echo
}

url_path_depth() {
  local URLPATH=${1#*://}
  URLPATH=${URLPATH#*/}
  URLPATH=${URLPATH%/}
  if [[ -z "$URLPATH" ]]; then
    echo 0
  else
    local PARTS
    IFS=/ read -ra PARTS <<< "$URLPATH"
    echo "${#PARTS[@]}"
  fi
}

fix_perms() {
  sudo chown -R $USER:$USER "$1"
  chmod -R ugo+r "$1"
  chmod -R u+w "$1"
  chmod -R go-w "$1"
  if [[ -d "$1" ]]; then
    find "$1" -type d | xargs chmod ugo+x
  fi
}

retro_msys2_mingw_package_prefix() {
  case "${MSYSTEM:-}" in
    MINGW32)
      echo mingw-w64-i686
      ;;
    MINGW64)
      echo mingw-w64-x86_64
      ;;
    UCRT64)
      echo mingw-w64-ucrt-x86_64
      ;;
    CLANG32)
      echo mingw-w64-clang-i686
      ;;
    CLANG64)
      echo mingw-w64-clang-x86_64
      ;;
    CLANGARM64)
      echo mingw-w64-clang-aarch64
      ;;
    *)
      return 1
      ;;
  esac
}

retro_install_prereq_packages() {
  if [[ $# -lt 2 ]]; then
    echo "Usage: retro_install_prereq_packages PACKAGE_MANAGER PACKAGE..."
    exit 1
  fi

  local PACKAGE_MANAGER=$1
  shift
  local INSTALL=()
  case $PACKAGE_MANAGER in
    brew)
      INSTALL=(brew install)
      ;;
    apt-get)
      INSTALL=(sudo apt-get install)
      ;;
    dnf)
      INSTALL=(sudo dnf install)
      ;;
    pacman)
      INSTALL=(sudo pacman -S --needed)
      ;;
    msys2-pacman)
      INSTALL=(pacman -S --needed)
      ;;
    *)
      echo "Unsupported package manager: $PACKAGE_MANAGER"
      exit 1
      ;;
  esac

  echo "Installing prerequisites with $PACKAGE_MANAGER:"
  printf '  %s\n' "$@"
  echo

  if [[ "${RETRO_PREREQ_DRY_RUN:-0}" == "1" ]]; then
    printf 'Dry run:'
    printf ' %q' "${INSTALL[@]}" "$@"
    echo
    return
  fi

  "${INSTALL[@]}" "$@"
}

retro_prereq() {
  local DRY_RUN=0
  if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
  fi
  if [[ $# -gt 0 ]]; then
    echo "Unknown prereq option: $1"
    exit 1
  fi

  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        RETRO_PREREQ_DRY_RUN=$DRY_RUN retro_install_prereq_packages brew qemu p7zip unzip wget bchunk xorriso
        return
      fi
      ;;
    MSYS_NT* | MINGW*_NT* | UCRT*_NT* | CLANG*_NT*)
      if command -v pacman >/dev/null 2>&1; then
        local MINGW_PACKAGE_PREFIX
        if ! MINGW_PACKAGE_PREFIX=$(retro_msys2_mingw_package_prefix); then
          cat <<EOF
MSYS2 detected, but no supported MinGW environment is active.

Run this from an MSYS2 MinGW shell such as UCRT64, MINGW64, CLANG64, or
CLANGARM64 so QEMU can be installed from the matching MinGW package repo.
EOF
          exit 1
        fi
        RETRO_PREREQ_DRY_RUN=$DRY_RUN retro_install_prereq_packages msys2-pacman "${MINGW_PACKAGE_PREFIX}-qemu" p7zip unzip wget xorriso openssh
        return
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        RETRO_PREREQ_DRY_RUN=$DRY_RUN retro_install_prereq_packages apt-get qemu-system-x86 qemu-system-arm qemu-system-gui qemu-utils p7zip-full unzip wget bchunk xorriso openssh-client
        return
      elif command -v dnf >/dev/null 2>&1; then
        RETRO_PREREQ_DRY_RUN=$DRY_RUN retro_install_prereq_packages dnf qemu-system-x86-core qemu-system-aarch64-core qemu-img qemu-ui-gtk 7zip unzip wget bchunk xorriso openssh-clients
        return
      elif command -v pacman >/dev/null 2>&1; then
        RETRO_PREREQ_DRY_RUN=$DRY_RUN retro_install_prereq_packages pacman qemu-system-x86 qemu-system-aarch64 qemu-ui-gtk qemu-img p7zip unzip wget bchunk xorriso openssh
        return
      fi
      ;;
  esac

  if command -v brew >/dev/null 2>&1; then
    RETRO_PREREQ_DRY_RUN=$DRY_RUN retro_install_prereq_packages brew qemu p7zip unzip wget bchunk xorriso
  else
    cat <<EOF
No supported package manager found.

Install the prerequisites manually:
  qemu-system-i386
  qemu-system-x86_64
  qemu-system-aarch64
  qemu-img
  QEMU window display backend
  7z
  unzip
  wget
  bchunk
  xorriso
  ssh, sftp, scp, and ssh-keygen
EOF
    exit 1
  fi
}
