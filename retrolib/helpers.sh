# shellcheck shell=bash
# Shared shell helpers used across download, extract, autoinstall, and QEMU code.

# Prints a file followed by one extra newline.
cat_newline() {
    cat "$1"
    echo
}

# Counts path components in a URL for wget cut-dirs.
url_path_depth() {
    local url_path=${1#*://}
    url_path=${url_path#*/}
    url_path=${url_path%/}
    if [[ -z "$url_path" ]]; then
        echo 0
    else
        local parts
        IFS=/ read -ra parts <<<"$url_path"
        echo "${#parts[@]}"
    fi
}

# Quotes one argument for safe, readable reuse on a POSIX shell command line.
# Single-quotes only when the argument contains characters outside a safe set,
# so ordinary tokens (including ones with ',' and '=') stay unquoted. This avoids
# the noisy backslash escaping that bash 3.2 'printf %q' adds to commas, etc.
shell_quote_word() {
    local s=$1
    case $s in
    '' | *[!a-zA-Z0-9,._=:/@%+-]*)
        s=\'${s//\'/\'\\\'\'}\'
        ;;
    esac
    printf '%s' "$s"
}

# Tests whether a path is a safe relative path: not empty, not absolute, and with
# no '..' component, so it cannot escape its intended destination directory.
path_is_safe_relative() {
    local path=$1 component
    case $path in
    '' | /*) return 1 ;;
    esac
    while :; do
        component=${path%%/*}
        if [[ $component == ".." ]]; then
            return 1
        fi
        [[ $path == */* ]] || break
        path=${path#*/}
    done
    return 0
}

# Finds a config file in the config directory or its parent.
retro_config_file() {
    local dir name path parent
    if [[ $# -eq 1 ]]; then
        dir=$CONFDIR
        name=$1
    elif [[ $# -eq 2 ]]; then
        dir=$1
        name=$2
    else
        log_error "Usage: retro_config_file [DIR] FILE"
        return 1
    fi

    path=$dir/$name
    if [[ -f "$path" ]]; then
        printf '%s\n' "$path"
        return 0
    fi

    parent=$(dirname "$dir")
    path=$parent/$name
    if [[ "$parent" != "$dir" && -f "$path" ]]; then
        printf '%s\n' "$path"
        return 0
    fi

    return 1
}

# Maps the active MSYS2 environment to its MinGW package prefix.
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

# Installs prerequisite packages using the selected package manager.
retro_install_prereq_packages() {
    local package_manager install
    if [[ $# -lt 2 ]]; then
        die "Usage: retro_install_prereq_packages PACKAGE_MANAGER PACKAGE..."
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
            RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages brew qemu p7zip unzip wget bchunk xorriso jq
            return
        fi
        ;;
    MSYS_NT* | MINGW*_NT* | UCRT*_NT* | CLANG*_NT*)
        if command -v pacman >/dev/null 2>&1; then
            if ! mingw_package_prefix=$(retro_msys2_mingw_package_prefix); then
                log_error "MSYS2 detected, but no supported MinGW environment is active."
                cat >&2 <<EOF
Run this from an MSYS2 MinGW shell such as UCRT64, MINGW64, CLANG64, or
CLANGARM64 so QEMU can be installed from the matching MinGW package repo.
EOF
                exit 1
            fi
            log_debug "Selected MSYS2 pacman prerequisite installer"
            RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages msys2-pacman "${mingw_package_prefix}-qemu" p7zip unzip wget xorriso lsof openssh jq
            return
        fi
        ;;
    Linux)
        if command -v apt-get >/dev/null 2>&1; then
            log_debug "Selected apt-get prerequisite installer"
            RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages apt-get qemu-system-x86 qemu-system-arm qemu-system-gui qemu-utils p7zip-full unzip wget bchunk xorriso lsof openssh-client jq
            return
        elif command -v dnf >/dev/null 2>&1; then
            log_debug "Selected dnf prerequisite installer"
            RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages dnf qemu-system-x86-core qemu-system-aarch64-core qemu-img qemu-ui-gtk 7zip unzip wget bchunk xorriso lsof openssh-clients jq
            return
        elif command -v pacman >/dev/null 2>&1; then
            log_debug "Selected pacman prerequisite installer"
            RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages pacman qemu-system-x86 qemu-system-aarch64 qemu-ui-gtk qemu-img p7zip unzip wget bchunk xorriso lsof openssh jq
            return
        fi
        ;;
    esac

    if command -v brew >/dev/null 2>&1; then
        log_debug "Selected fallback Homebrew prerequisite installer"
        RETRO_PREREQ_DRY_RUN=$dry_run retro_install_prereq_packages brew qemu p7zip unzip wget bchunk xorriso jq
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
  unzip
  wget
  bchunk
  xorriso
  lsof
  jq
  ssh, sftp, scp, and ssh-keygen
EOF
        exit 1
    fi
}

# Stages the shared and distro-specific autoinstall files on the FAT media.
autoinst_prep() {
    local autoinst_d=$EXTRACTDIR/fat/autoinst.d
    local autoinst_file autoconf_file
    log_info "Staging autoinstall runtime"
    cp "$AUTOBASE/autoinst.sh" "$EXTRACTDIR/fat/autoinst"
    rm -rf "$autoinst_d"
    mkdir -p "$autoinst_d"
    cp -R "$AUTOBASE"/. "$autoinst_d"
    mkdir -p "$autoinst_d/distro"
    if autoinst_file=$(retro_config_file autoinst.sh); then
        log_debug "Staging distro autoinst manifest $autoinst_file"
        cp "$autoinst_file" "$autoinst_d/distro/autoinst.sh"
    else
        log_debug "No distro autoinst manifest configured"
    fi
    if autoconf_file=$(retro_config_file autoconf.sh); then
        log_debug "Staging distro autoconf manifest $autoconf_file"
        cp "$autoconf_file" "$autoinst_d/distro/autoconf.sh"
    else
        log_debug "No distro autoconf manifest configured"
    fi
    slackware_prepare_tagfiles
}
