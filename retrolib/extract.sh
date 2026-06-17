# shellcheck shell=bash
# Extraction helpers for mounting media images and building the staged install tree.

# Updates boot.img and root.img symlinks to extracted image names.
retro_link_boot_root() {
    local boot_image=${1:-}
    local root_image=${2:-}

    if [[ -n "$boot_image" ]]; then
        ln -sfn "$boot_image" boot.img
    fi
    if [[ -n "$root_image" ]]; then
        ln -sfn "$root_image" root.img
    fi
}

# Extracts selected FAT image files into a lowercase destination tree.
debian_extract_fat_image() {
    local image=$1
    local dest=$2
    local file lower
    shift 2

    if [[ -e "$dest" || -L "$dest" ]]; then
        chmod -R u+w "$dest" 2>/dev/null || true
        rm -rf "$dest"
    fi
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

# Updates install.iso when the extraction source is an ISO.
extract_link_install_iso() {
    local source=${1:-}
    case "$source" in
    *.iso)
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
        truncate -s 1440k "$image"
    fi
}

# Extracts boot, root, and extra images from an archive source.
extract_install_archive_images() {
    local source=$1
    shift
    if [[ $# -gt 0 ]]; then
        if extract_install_is_tar_stream "$source"; then
            7z x -so "$source" | 7z e -y -si -ttar "$@" >/dev/null
        else
            7z e -y "$source" "$@" >/dev/null
        fi
    fi
}

# Extracts individual files from an archive source into fat/.
extract_install_archive_fat_files() {
    local source=$1
    shift
    if [[ $# -gt 0 ]]; then
        mkdir -p fat
        if extract_install_is_tar_stream "$source"; then
            7z x -so "$source" | 7z e -y -si -ttar -ofat "$@" >/dev/null
        else
            7z e -y -ofat "$source" "$@" >/dev/null
        fi
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

    if [[ "$packages" == "." ]]; then
        mkdir -p fat/packages
        if extract_install_is_tar_stream "$source"; then
            7z x -so "$source" | 7z x -y -si -ttar -ofat/packages >/dev/null
        else
            7z x -y -ofat/packages "$source" >/dev/null
        fi
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
            cp -p "$source_file" "$target"
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
        cp -p "$source_file" fat/
    done
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
    rm -f fat/packages
    mkdir -p fat/packages
    cp -pR "$source_file"/. fat/packages/
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

    if declare -p EXTRACT_EXTRA_IMAGES >/dev/null 2>&1; then
        eval "extra_images=(\"\${EXTRACT_EXTRA_IMAGES[@]}\")"
    fi
    if declare -p EXTRACT_FAT_FILES >/dev/null 2>&1; then
        eval "fat_files=(\"\${EXTRACT_FAT_FILES[@]}\")"
    fi

    if [[ $# -gt 0 ]]; then
        echo "extract_install_files is controlled by EXTRACT_* variables, not arguments." >&2
        extract_install_files_reset
        return 1
    fi
    if [[ -z "$boot_image" && -z "$root_image" && -z "$packages" && ${#extra_images[@]} -eq 0 && ${#fat_files[@]} -eq 0 ]]; then
        echo "Set EXTRACT_BOOT_IMAGE, EXTRACT_ROOT_IMAGE, EXTRACT_EXTRA_IMAGES, EXTRACT_FAT_FILES, or EXTRACT_PACKAGES before calling extract_install_files." >&2
        extract_install_files_reset
        return 1
    fi
    # EXTRACT_PACKAGES can be absolute (a pre-built source directory) or relative
    # (an in-archive path used as a 7z filter and for rm -rf/mv under fat/).
    # Only reject '..' components, which would let rm -rf escape fat/.
    case "${packages#./}" in
        .. | ../* | */.. | */../*)
            echo "Refusing unsafe EXTRACT_PACKAGES path: $packages" >&2
            extract_install_files_reset
            return 1
            ;;
    esac

    [[ -n "$boot_image" ]] && image_files+=("$boot_image")
    [[ -n "$root_image" ]] && image_files+=("$root_image")
    image_files+=("${extra_images[@]}")

    source=$(extract_install_resolve_source "$source")
    extract_link_install_iso "$source"
    if [[ -n "$source" && ! -d "$source" ]]; then
        extract_install_archive_images "$source" "${image_files[@]}"
        extract_install_archive_fat_files "$source" "${fat_files[@]}"
        extract_install_archive_packages "$source" "$packages"
    else
        extract_install_copy_images "$source" "${image_files[@]}"
        extract_install_copy_fat_files "$source" "${fat_files[@]}"
        extract_install_copy_packages "$source" "$packages"
    fi

    retro_link_boot_root "${boot_image##*/}" "${root_image##*/}"
    extract_install_files_reset
}

# Top-level retro command handler for extracting and staging a distro.
retro_extract() {
    local extract_file autoinst_file
    retro_download
    if [[ ! -f $EXTRACTDIR/.extracted ]]; then
        extract_file=$(retro_config_file extract.sh || true)
        autoinst_file=$(retro_config_file autoinst.sh || true)
        if [[ -n "$extract_file" || -n "$autoinst_file" ]]; then
            mkdir -p "$EXTRACTDIR"
            pushd "$EXTRACTDIR" >/dev/null || return
            if [[ -n "$extract_file" ]]; then
                # shellcheck source=/dev/null
                source "$extract_file"
            fi
            if [[ -n "$autoinst_file" ]]; then
                mkdir -p "$EXTRACTDIR/fat"
                load_qemu_config
                autoinst_prep
            fi
            touch "$EXTRACTDIR/.extracted"
            popd >/dev/null || return
        else
            echo "Nothing to extract"
        fi
    else
        echo "Using extracted files"
        autoinst_file=$(retro_config_file autoinst.sh || true)
        if [[ -n "$autoinst_file" ]]; then
            mkdir -p "$EXTRACTDIR/fat"
            pushd "$EXTRACTDIR" >/dev/null || return
            load_qemu_config
            autoinst_prep
            popd >/dev/null || return
        fi
    fi
}
