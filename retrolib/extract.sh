# shellcheck shell=bash
# Extraction helpers for mounting media images and building the staged install tree.

# Updates a canonical image name to point at an extracted image name.
retro_link_image_name() {
    local link_name=$1
    local image=${2:-}
    local image_name=${image##*/}

    if [[ -z "$image_name" ]]; then
        return
    fi

    if [[ "$image_name" == "$link_name" ]]; then
        log_debug "Install image already named $link_name"
        return
    fi

    log_debug "Linking $link_name -> $image_name"
    ln -sfn "$image_name" "$link_name"
}

# Updates boot.img and root.img symlinks to extracted image names.
retro_link_boot_root() {
    local boot_image=${1:-}
    local root_image=${2:-}

    retro_link_image_name boot.img "$boot_image"
    retro_link_image_name root.img "$root_image"
}

# Extracts selected FAT image files into a lowercase destination tree.
debian_extract_fat_image() {
    local image=$1
    local dest=$2
    local file lower
    shift 2

    if [[ -e "$dest" || -L "$dest" ]]; then
        log_debug "Replacing existing FAT extraction directory $dest"
        chmod -R u+w "$dest" 2>/dev/null || true
        rm -rf "$dest"
    fi
    log_info "Extracting FAT image $image"
    mkdir -p "$dest"
    7z x -y -aoa -o"$dest" "$image" "$@" >/dev/null
    for file in "$dest"/*; do
        lower=$(echo "${file##*/}" | tr '[:upper:]' '[:lower:]')
        if [[ "${file##*/}" != "$lower" ]]; then
            mv "$file" "$dest/$lower"
        fi
    done
}

# Clears EXTRACT_* control variables after an extraction pass.
extract_install_files_reset() {
    EXTRACT_SOURCE=
    EXTRACT_BOOT_IMAGE=
    EXTRACT_ROOT_IMAGE=
    EXTRACT_EXTRA_IMAGES=()
    EXTRACT_FAT_FILES=()
    EXTRACT_PACKAGES=
}

# Resolves the configured extraction source against ORIGDIR.
extract_install_resolve_source() {
    local source=${1:-}
    if [[ -z "$source" ]]; then
        printf '%s\n' "${ORIGDIR:-}"
    elif [[ "$source" != /* ]]; then
        printf '%s\n' "${ORIGDIR:+$ORIGDIR/}$source"
    else
        printf '%s\n' "$source"
    fi
}

# Resolves a file path against a directory extraction source.
extract_install_source_file() {
    local source=${1:-}
    local file=${2:-}
    if [[ -n "$source" && "$file" != /* ]]; then
        printf '%s\n' "$source/$file"
    else
        printf '%s\n' "$file"
    fi
}

# Tests whether an extraction source should be streamed as tar.
extract_install_is_tar_stream() {
    case $1 in
    *.tar.gz | *.tgz) return 0 ;;
    esac
    return 1
}

# Makes generated qemu.d staging artifacts writable by the current user.
extract_make_user_writable() {
    local path
    for path in "$@"; do
        [[ -e "$path" || -L "$path" ]] || continue
        if [[ -d "$path" && ! -L "$path" ]]; then
            chmod -R u+rwX "$path" 2>/dev/null || true
        else
            chmod u+rw "$path" 2>/dev/null || true
        fi
    done
}

# Updates install.iso when the extraction source is an ISO.
extract_link_install_iso() {
    local source=${1:-}
    case "$source" in
    *.iso)
        log_info "Linking install.iso to $source"
        ln -sfn "$source" install.iso
        ;;
    esac
}

# Normalizes extracted boot floppy images to a 1.44M disk size.
extract_truncate_floppy_image() {
    local image=${1:-}
    case "$image" in
    *.gz) return 0 ;;
    esac
    if [[ -n "$image" && -f "$image" ]]; then
        log_debug "Normalizing floppy image size for $image"
        truncate -s 1440k "$image"
    fi
}

# Stages a Red Hat Kickstart file on a floppy image.
redhat_stage_kickstart() {
    local boot_image=${1:-boot.img}
    local kickstart
    local stripped_kickstart
    local help_file
    local status

    case ${CONFNAME:-} in
    redhat/*) ;;
    *) return 0 ;;
    esac

    kickstart=$(retro_config_file ks.cfg || true)
    if [[ -z "$kickstart" ]]; then
        return 0
    fi
    if ! command -v mcopy >/dev/null 2>&1; then
        log_error "mcopy is required to add ${kickstart##*/} to $boot_image. Run retro prereq to install mtools."
        return 1
    fi
    if [[ -e "$boot_image" && ! -f "$boot_image" ]]; then
        log_error "Kickstart file configured, but $boot_image is not a regular file."
        return 1
    fi
    if [[ ! -f "$boot_image" ]]; then
        log_warn "Kickstart file configured, but boot image $boot_image was not staged."
        return 0
    fi

    stripped_kickstart=$(mktemp "${TEMPDIR:-${TMPDIR:-/tmp}}/ks.cfg.XXXXXX") || return 1
    sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$kickstart" >"$stripped_kickstart" || {
        rm -f "$stripped_kickstart"
        return 1
    }

    log_info "Adding stripped ${kickstart##*/} to Red Hat floppy image $boot_image"
    if mcopy -o -i "$boot_image" "$stripped_kickstart" ::ks.cfg 2>/dev/null; then
        rm -f "$stripped_kickstart"
        return 0
    fi

    log_warn "Kickstart file did not fit; removing Red Hat boot help messages and retrying."
    for help_file in expert.msg general.msg kickit.msg param.msg rescue.msg examples.msg; do
        mdel -i "$boot_image" "::$help_file" >/dev/null 2>&1 || true
    done
    mcopy -o -i "$boot_image" "$stripped_kickstart" ::ks.cfg
    status=$?
    rm -f "$stripped_kickstart"
    return "$status"
}

# Extracts boot, root, and extra images from an archive source.
extract_install_archive_images() {
    local source=$1
    shift
    if [[ $# -gt 0 ]]; then
        log_info "Extracting install images from ${source##*/}"
        if extract_install_is_tar_stream "$source"; then
            7z x -so "$source" | 7z e -y -si -ttar "$@" >/dev/null
        else
            7z e -y "$source" "$@" >/dev/null
        fi
        extract_make_user_writable "${@##*/}"
    fi
}

# Extracts individual files from an archive source into fat/.
extract_install_archive_fat_files() {
    local source=$1
    shift
    if [[ $# -gt 0 ]]; then
        log_info "Extracting FAT files from ${source##*/}"
        mkdir -p fat
        if extract_install_is_tar_stream "$source"; then
            7z x -so "$source" | 7z e -y -si -ttar -ofat "$@" >/dev/null
        else
            7z e -y -ofat "$source" "$@" >/dev/null
        fi
        extract_make_user_writable fat
    fi
}

# Extracts a package directory from an archive source into fat/packages.
extract_install_archive_packages() {
    local source=$1
    local packages=$2
    local package_root
    local package_target

    if [[ -z "$packages" ]]; then
        return
    fi

    log_info "Extracting package tree $packages from ${source##*/}"
    if [[ "$packages" == "." ]]; then
        mkdir -p fat/packages
        if extract_install_is_tar_stream "$source"; then
            7z x -so "$source" | 7z x -y -si -ttar -ofat/packages >/dev/null
        else
            7z x -y -ofat/packages "$source" >/dev/null
        fi
        extract_make_user_writable fat/packages
    else
        mkdir -p fat
        package_target=${packages#./}
        package_root=${package_target%%/*}
        rm -rf fat/packages "fat/$package_root"
        if extract_install_is_tar_stream "$source"; then
            7z x -so "$source" | 7z x -y -si -ttar -ofat "$packages/*" >/dev/null
        else
            7z x -y -ofat "$source" "$packages/*" >/dev/null
        fi
        mv "fat/$package_target" fat/packages
        rm -rf "fat/$package_root"
        extract_make_user_writable fat/packages
    fi
}

# Copies boot, root, and extra images from a directory source.
extract_install_copy_images() {
    local source=$1
    local file source_file target
    shift

    for file in "$@"; do
        source_file=$(extract_install_source_file "$source" "$file")
        target=${file##*/}
        if [[ "$file" != "$target" || ! -e "$target" ]]; then
            log_info "Copying install image $file"
            cp "$source_file" "$target"
            extract_make_user_writable "$target"
        else
            log_debug "Install image already staged: $target"
            extract_make_user_writable "$target"
        fi
    done
}

# Copies individual files from a directory source into fat/.
extract_install_copy_fat_files() {
    local source=$1
    local file source_file
    shift

    if [[ $# -eq 0 ]]; then
        return
    fi

    mkdir -p fat
    for file in "$@"; do
        source_file=$(extract_install_source_file "$source" "$file")
        log_info "Copying FAT file $file"
        cp "$source_file" fat/
    done
    extract_make_user_writable fat
}

# Copies a package directory from a directory source into fat/packages.
extract_install_copy_packages() {
    local source=$1
    local packages=$2
    local source_file

    if [[ -z "$packages" ]]; then
        return
    fi
    source_file=$(extract_install_source_file "$source" "$packages")
    log_info "Copying package tree $packages"
    rm -f fat/packages
    mkdir -p fat/packages
    cp -R "$source_file"/. fat/packages/
    extract_make_user_writable fat/packages
}

# Extracts or copies configured install media into qemu.d.
extract_install_files() {
    local source=${EXTRACT_SOURCE:-}
    local boot_image=${EXTRACT_BOOT_IMAGE:-}
    local root_image=${EXTRACT_ROOT_IMAGE:-}
    local packages=${EXTRACT_PACKAGES:-}
    local image_files=()
    local extra_images=()
    local fat_files=()

    [[ -n ${EXTRACT_EXTRA_IMAGES+x} ]] && extra_images=("${EXTRACT_EXTRA_IMAGES[@]}")
    [[ -n ${EXTRACT_FAT_FILES+x} ]] && fat_files=("${EXTRACT_FAT_FILES[@]}")

    if [[ $# -gt 0 ]]; then
        log_error "extract_install_files is controlled by EXTRACT_* variables, not arguments."
        extract_install_files_reset
        return 1
    fi
    if [[ -z "$boot_image" && -z "$root_image" && -z "$packages" && ${#extra_images[@]} -eq 0 && ${#fat_files[@]} -eq 0 ]]; then
        log_error "Set EXTRACT_BOOT_IMAGE, EXTRACT_ROOT_IMAGE, EXTRACT_EXTRA_IMAGES, EXTRACT_FAT_FILES, or EXTRACT_PACKAGES before calling extract_install_files."
        extract_install_files_reset
        return 1
    fi
    # EXTRACT_PACKAGES can be absolute (a pre-built source directory) or relative
    # (an in-archive path used as a 7z filter and for rm -rf/mv under fat/).
    # Only reject '..' components, which would let rm -rf escape fat/.
    case "${packages#./}" in
        .. | ../* | */.. | */../*)
            log_error "Refusing unsafe EXTRACT_PACKAGES path: $packages"
            extract_install_files_reset
            return 1
            ;;
    esac

    [[ -n "$boot_image" ]] && image_files+=("$boot_image")
    [[ -n "$root_image" ]] && image_files+=("$root_image")
    image_files+=("${extra_images[@]}")

    source=$(extract_install_resolve_source "$source")
    log_info "Staging install files from ${source:-download directory}"
    log_debug "Images: ${image_files[*]:-(none)}"
    log_debug "FAT files: ${fat_files[*]:-(none)}"
    log_debug "Packages: ${packages:-(none)}"
    extract_link_install_iso "$source"
    if [[ -n "$source" && ! -d "$source" ]]; then
        log_debug "Extraction source is an archive or image"
        extract_install_archive_images "$source" "${image_files[@]}"
        extract_install_archive_fat_files "$source" "${fat_files[@]}"
        extract_install_archive_packages "$source" "$packages"
    else
        log_debug "Extraction source is a directory"
        extract_install_copy_images "$source" "${image_files[@]}"
        extract_install_copy_fat_files "$source" "${fat_files[@]}"
        extract_install_copy_packages "$source" "$packages"
    fi

    retro_link_boot_root "${boot_image##*/}" "${root_image##*/}"
    extract_install_files_reset
}

# Top-level retro command handler for extracting and staging a distro.
retro_extract() {
    local extract_file status
    log_debug "Starting extraction for $CONFNAME"
    retro_download
    if [[ ! -f $EXTRACTDIR/.extracted ]]; then
        extract_file=$(retro_config_file extract.sh || true)
        if [[ -z "$extract_file" ]]; then
            die "No extract.sh configured for $CONFNAME"
        fi
        mkdir -p "$EXTRACTDIR"
        log_info "Running extract script $extract_file"
        pushd "$EXTRACTDIR" >/dev/null || return
        # shellcheck source=/dev/null
        source "$extract_file" || {
            status=$?
            popd >/dev/null || return
            return "$status"
        }
        touch "$EXTRACTDIR/.extracted"
        popd >/dev/null || return
        log_info "Extraction step complete for $CONFNAME"
    else
        log_debug "Using extracted files"
    fi

    pushd "$EXTRACTDIR" >/dev/null || return
    extract_make_user_writable boot.img root.img fat
    redhat_stage_kickstart boot.img || return
    autoinst_prep
    popd >/dev/null || return
}
