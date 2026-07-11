# shellcheck shell=bash
# Host prerequisite installation helpers.

# Maps the active MSYS2 environment to its MinGW package prefix.
prereq_detect_msys2_prefix() {
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

# Installs prerequisite packages using the selected package manager.
prereq_install_packages() {
    local package_manager install
    if [[ $# -lt 2 ]]; then
        die "Usage: prereq_install_packages PACKAGE_MANAGER PACKAGE..."
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
        die "Unsupported package manager: $package_manager"
        ;;
    esac

    log_info "Installing prerequisites with $package_manager:"
    printf '  %s\n' "$@"
    echo

    if [[ "${RETRO_PREREQ_DRY_RUN:-0}" == "1" ]]; then
        log_info "Prerequisite dry run enabled"
        printf 'Dry run:'
        printf ' %q' "${install[@]}" "$@"
        echo
        return
    fi

    "${install[@]}" "$@"
}

# Top-level retro command handler for installing host prerequisites.
retro_prereq() {
    local dry_run=0
    local mingw_package_prefix
    log_info "Checking host prerequisite installer"
    if [[ "${1:-}" == "--dry-run" ]]; then
        dry_run=1
        shift
    fi
    if [[ $# -gt 0 ]]; then
        die "Unknown prereq option: $1"
    fi

    case "$(uname -s)" in
    Darwin)
        if command -v brew >/dev/null 2>&1; then
            log_debug "Selected Homebrew prerequisite installer"
            RETRO_PREREQ_DRY_RUN=$dry_run prereq_install_packages brew qemu p7zip unzip wget bchunk xorriso jq mtools
            return
        fi
        ;;
    MSYS_NT* | MINGW*_NT* | UCRT*_NT* | CLANG*_NT*)
        if command -v pacman >/dev/null 2>&1; then
            if ! mingw_package_prefix=$(prereq_detect_msys2_prefix); then
                log_error "MSYS2 detected, but no supported MinGW environment is active."
                cat >&2 <<EOF
Run this from an MSYS2 MinGW shell such as UCRT64, MINGW64, CLANG64, or
CLANGARM64 so QEMU can be installed from the matching MinGW package repo.
EOF
                exit 1
            fi
            log_debug "Selected MSYS2 pacman prerequisite installer"
            RETRO_PREREQ_DRY_RUN=$dry_run prereq_install_packages msys2-pacman "${mingw_package_prefix}-qemu" p7zip unzip wget xorriso lsof jq mtools
            return
        fi
        ;;
    Linux)
        if command -v apt-get >/dev/null 2>&1; then
            log_debug "Selected apt-get prerequisite installer"
            RETRO_PREREQ_DRY_RUN=$dry_run prereq_install_packages apt-get qemu-system-x86 qemu-system-arm qemu-system-gui qemu-utils p7zip-full unzip wget bchunk xorriso lsof jq mtools
            return
        elif command -v dnf >/dev/null 2>&1; then
            log_debug "Selected dnf prerequisite installer"
            RETRO_PREREQ_DRY_RUN=$dry_run prereq_install_packages dnf qemu-system-x86-core qemu-system-aarch64-core qemu-img qemu-ui-gtk 7zip unzip wget bchunk xorriso lsof jq mtools
            return
        elif command -v pacman >/dev/null 2>&1; then
            log_debug "Selected pacman prerequisite installer"
            RETRO_PREREQ_DRY_RUN=$dry_run prereq_install_packages pacman qemu-system-x86 qemu-system-aarch64 qemu-ui-gtk qemu-img p7zip unzip wget bchunk xorriso lsof jq mtools
            return
        fi
        ;;
    esac

    if command -v brew >/dev/null 2>&1; then
        log_debug "Selected fallback Homebrew prerequisite installer"
        RETRO_PREREQ_DRY_RUN=$dry_run prereq_install_packages brew qemu p7zip unzip wget bchunk xorriso jq mtools
    else
        log_error "No supported package manager found."
        cat >&2 <<EOF
Install the prerequisites manually:
  qemu-system-i386
  qemu-system-x86_64
  qemu-system-aarch64
  qemu-img
  QEMU window display backend
  7z
  mcopy
  unzip
  wget
  bchunk
  xorriso
  lsof
  jq
EOF
        exit 1
    fi
}
