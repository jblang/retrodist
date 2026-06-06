# shellcheck shell=bash
# Shared shell helpers used across download, extract, autoinstall, and QEMU code.
cat_newline() {
  cat "$1"
  echo
}

url_path_depth() {
  local url_path=${1#*://}
  url_path=${url_path#*/}
  url_path=${url_path%/}
  if [[ -z "$url_path" ]]; then
    echo 0
  else
    local parts
    IFS=/ read -ra parts <<< "$url_path"
    echo "${#parts[@]}"
  fi
}

fix_perms() {
  sudo chown -R "$USER:$USER" "$1"
  chmod -R ugo+r "$1"
  chmod -R u+w "$1"
  chmod -R go-w "$1"
  if [[ -d "$1" ]]; then
    find "$1" -type d -exec chmod ugo+x {} +
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
  local package_manager install
  if [[ $# -lt 2 ]]; then
    echo "Usage: retro_install_prereq_packages PACKAGE_MANAGER PACKAGE..."
    exit 1
  fi

  package_manager=$1
  shift
  install=()
  case $package_manager in
    brew)
      install=(brew install)
      ;;
    apt-get)
      install=(sudo apt-get install)
      ;;
    dnf)
      install=(sudo dnf install)
      ;;
    pacman)
      install=(sudo pacman -S --needed)
      ;;
    msys2-pacman)
      install=(pacman -S --needed)
      ;;
    *)
      echo "Unsupported package manager: $package_manager"
      exit 1
      ;;
  esac

  echo "Installing prerequisites with $package_manager:"
  printf '  %s\n' "$@"
  echo

  if [[ "${RETRO_PREREQ_DRY_RUN:-0}" == "1" ]]; then
    printf 'Dry run:'
    printf ' %q' "${install[@]}" "$@"
    echo
    return
  fi

  "${install[@]}" "$@"
}

retro_prereq() {
  local dry_run=0
  local mingw_package_prefix
  if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=1
    shift
  fi
  if [[ $# -gt 0 ]]; then
    echo "Unknown prereq option: $1"
    exit 1
  fi

  case "$(uname -s)" in
    Darwin)
      if command -v brew >/dev/null 2>&1; then
        RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages brew qemu p7zip unzip wget bchunk xorriso
        return
      fi
      ;;
    MSYS_NT* | MINGW*_NT* | UCRT*_NT* | CLANG*_NT*)
      if command -v pacman >/dev/null 2>&1; then
        if ! mingw_package_prefix=$(retro_msys2_mingw_package_prefix); then
          cat <<EOF
MSYS2 detected, but no supported MinGW environment is active.

Run this from an MSYS2 MinGW shell such as UCRT64, MINGW64, CLANG64, or
CLANGARM64 so QEMU can be installed from the matching MinGW package repo.
EOF
          exit 1
        fi
        RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages msys2-pacman "${mingw_package_prefix}-qemu" p7zip unzip wget xorriso lsof openssh
        return
      fi
      ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages apt-get qemu-system-x86 qemu-system-arm qemu-system-gui qemu-utils p7zip-full unzip wget bchunk xorriso lsof openssh-client
        return
      elif command -v dnf >/dev/null 2>&1; then
        RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages dnf qemu-system-x86-core qemu-system-aarch64-core qemu-img qemu-ui-gtk 7zip unzip wget bchunk xorriso lsof openssh-clients
        return
      elif command -v pacman >/dev/null 2>&1; then
        RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages pacman qemu-system-x86 qemu-system-aarch64 qemu-ui-gtk qemu-img p7zip unzip wget bchunk xorriso lsof openssh
        return
      fi
      ;;
  esac

  if command -v brew >/dev/null 2>&1; then
    RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages brew qemu p7zip unzip wget bchunk xorriso
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
  lsof
  ssh, sftp, scp, and ssh-keygen
EOF
    exit 1
  fi
}
