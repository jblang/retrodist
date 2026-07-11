# shellcheck shell=bash
# Download helpers for mirrors, per-distro manifests, and recursive asset fetches.

# Tests whether a path is safe, relative, and unable to escape its destination.
download_path_is_safe_relative() {
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

# Counts path components in a URL for wget cut-dirs.
download_url_path_depth() {
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

# Downloads files listed as filename/url pairs in a manifest.
download_list() {
    local file url dest
    if [[ $# -ne 2 ]]; then
        die "Usage: download_list MANIFEST DESTDIR"
    fi
    log_debug "Reading download manifest $1"
    {
        cat "$1"
        echo
    } | while IFS=' ' read -r file url; do
        if [[ -n "$file" && -n "$url" ]]; then
            if ! download_path_is_safe_relative "$file"; then
                log_error "Refusing unsafe download path: $file"
                continue
            fi
            dest=$2/$file
            if [[ ! -f "$dest" ]]; then
                log_info "Downloading $file"
                wget --no-verbose --show-progress -O "$dest" "$url"
            else
                log_debug "Already downloaded: $file"
            fi
        fi
    done
}

# Downloads named files from a base URL into a destination directory.
download_files() {
    local url_base dest_base file
    if [[ $# -lt 3 ]]; then
        die "Usage: download_files URL_BASE DESTDIR FILE..."
    fi
    url_base=$1
    dest_base=$2
    shift 2
    log_info "Downloading selected files from $url_base"
    mkdir -p "$dest_base"
    for file in "$@"; do
        if [[ ! -f "$dest_base/$file" ]]; then
            log_info "Downloading $file"
            wget \
                --no-verbose \
                --show-progress \
                -O "$dest_base/$file" \
                "$url_base/$file"
        else
            log_debug "Already downloaded: $file"
        fi
    done
}

# Recursively downloads named directories from a base URL.
download_directories() {
    local url_base dest_base cut_dirs dir
    if [[ $# -lt 3 ]]; then
        die "Usage: download_directories URL_BASE DESTDIR DIR..."
    fi
    url_base=$1
    dest_base=$2
    shift 2
    log_info "Downloading selected directories from $url_base"
    mkdir -p "$dest_base"
    cut_dirs=$(download_url_path_depth "$url_base")
    for dir in "$@"; do
        if [[ ! -d "$dest_base/$dir" ]]; then
            log_info "Downloading directory $dir"
            wget \
                --no-verbose \
                --show-progress \
                --recursive \
                --no-parent \
                --no-host-directories \
                --cut-dirs="$cut_dirs" \
                --directory-prefix="$dest_base" \
                --reject "*index*" \
                "$url_base/$dir/"
        else
            log_debug "Already downloaded: $dir"
        fi
    done
}

# Downloads a Slackware release tree from the official mirror.
download_slackware() {
    local slack_base
    if [[ $# -ne 1 ]]; then
        die "Usage: download_slackware VERSION"
    fi
    slack_base=$PWD
    if [[ ! -d "$slack_base/slackware-$1" ]]; then
        log_info "Downloading Slackware $1 mirror tree"
        wget \
            --no-verbose \
            --show-progress \
            --recursive \
            --no-parent \
            --no-host-directories \
            --cut-dirs=1 \
            --directory-prefix="$slack_base" \
            --reject "*.md5*,*.meta4,*.sha*,*mirror*,*index*" \
            "http://mirrors.slackware.com/slackware/slackware-$1/"
    else
        log_debug "Already downloaded: slackware-$1"
    fi
}

# Downloads a Debian release tree from archive.debian.org.
download_debian() {
    local debian_base rel_base rel_url files dirs
    if [[ $# -ne 1 ]]; then
        die "Usage: download_debian RELEASE"
    fi
    debian_base=$PWD
    rel_base="$debian_base/$1"
    rel_url="https://archive.debian.org/debian/dists/$1"
    if [[ "$1" != "Debian-0.93R6" ]]; then
        rel_base="$rel_base/main"
        rel_url="$rel_url/main"
    fi
    files=("Contents-i386.gz")
    dirs=()
    case "$1" in
    Debian-0.93R6)
        files=("README.DEBIAN" "Contents")
        dirs=("ms-dos" "disks")
        ;;
    buzz)
        files=("README" "Contents")
        dirs=("msdos-i386" "disks-i386")
        ;;
    rex)
        files=("README" "Contents")
        dirs=("msdos-i386" "disks-i386")
        ;;
    bo)
        files=("README" "Contents-i386.gz")
        dirs=("msdos-i386" "disks-i386")
        ;;
    hamm | slink | potato | woody)
        dirs=("binary-i386" "disks-i386")
        ;;
    *)
        dirs=("binary-i386" "installer-i386")
        ;;
    esac
    log_info "Downloading Debian $1 release assets"
    download_files "$rel_url" "$rel_base" "${files[@]}"
    download_directories "$rel_url" "$rel_base" "${dirs[@]}"
}

# Resolves a distro's cdrom.txt reference to a cdrom config directory.
cdrom_config_dir() {
    local cdrom cdrom_file
    cdrom_file=$(qemu_config_find_file "$1" cdrom.txt) || return 1
    if [[ ! -f "$cdrom_file" ]]; then
        return 1
    fi
    cdrom=$(<"$cdrom_file")
    log_debug "Resolved cdrom.txt for $1 to cdrom/$cdrom"
    cd "$RETRO_D/cdrom/$cdrom" && pwd
}

# Runs all configured download mechanisms for a config directory.
download_config_assets() {
    local ver rel config_file
    log_debug "Checking download sources for $1"
    if config_file=$(qemu_config_find_file "$1" download.txt); then
        log_debug "Using download manifest $config_file"
        download_list "$config_file" "$2"
    fi
    if config_file=$(qemu_config_find_file "$1" slackmirror.txt); then
        ver=$(<"$config_file")
        log_debug "Using Slackware mirror config $config_file"
        (
            cd "$2" || exit
            download_slackware "$ver"
        )
    fi
    if config_file=$(qemu_config_find_file "$1" debmirror.txt); then
        rel=$(<"$config_file")
        log_debug "Using Debian mirror config $config_file"
        (
            cd "$2" || exit
            download_debian "$rel"
        )
    fi
    if config_file=$(qemu_config_find_file "$1" download.sh); then
        log_info "Running custom download script $config_file"
        pushd "$2" >/dev/null || return
        # shellcheck source=/dev/null
        source "$config_file"
        popd >/dev/null || return
    fi
}

# Downloads assets for the CD-ROM config referenced by a distro.
download_cdrom_assets() {
    local cdrom_dir cdrom_download
    cdrom_dir=$(cdrom_config_dir "$1") || return 0
    log_debug "Downloading referenced CD-ROM assets from $cdrom_dir"
    cdrom_download=$cdrom_dir/download.d
    mkdir -p "$cdrom_download"
    download_config_assets "$cdrom_dir" "$cdrom_download"
}

# Links downloaded CD-ROM ISO files into a distro extraction directory.
link_cdrom_isos() {
    local cdrom_dir cdrom_download file
    cdrom_dir=$(cdrom_config_dir "$1") || return 0
    log_debug "Linking referenced CD-ROM ISO files"
    cdrom_download=$cdrom_dir/download.d
    mkdir -p "$2"
    find "$cdrom_download" -maxdepth 1 -type f -iname '*.iso' -print | while IFS= read -r file; do
        log_debug "Linking ${file##*/} into $2"
        ln -sf "$file" "$2/${file##*/}"
    done
}

# Downloads both referenced CD-ROM assets and distro-specific assets.
download_all() {
    local cdrom_file
    log_debug "Preparing download directory $2"
    mkdir -p "$2"
    if cdrom_file=$(qemu_config_find_file "$1" cdrom.txt); then
        log_debug "Config references CD-ROM assets via $cdrom_file"
        download_cdrom_assets "$1"
        link_cdrom_isos "$1" "$2"
    fi
    download_config_assets "$1" "$2"
}

# Top-level retro command handler for downloading a distro.
retro_download() {
    local src
    log_debug "Starting downloads for $CONFNAME"
    for src in download.txt slackmirror.txt debmirror.txt download.sh cdrom.txt; do
        if qemu_config_find_file "$src" >/dev/null 2>&1; then
            log_debug "Found download source $src"
            download_all "$DISTRO_D" "$DOWNLOAD_D"
            log_debug "Download step complete for $CONFNAME"
            return
        fi
    done
    die "No download source configured for $CONFNAME"
}
