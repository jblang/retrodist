# shellcheck shell=bash
# Download helpers for mirrors, per-distro manifests, and recursive asset fetches.
download_list() {
  local file url dest
  if [[ $# -ne 2 ]]; then
    exit 1
  fi
  cat_newline "$1" | while IFS=' ' read -r file url; do
    dest=$2/$file
    if [[ -n "$file" && -n "$url" ]]; then
      if [[ ! -f "$dest" ]]; then
        echo "Downloading $file"
        wget --no-verbose --show-progress -O "$dest" "$url"
      else
        echo "Already downloaded: $file"
      fi
    fi
  done
}

download_files() {
  local url_base dest_base file
  if [[ $# -lt 3 ]]; then
    exit 1
  fi
  url_base=$1
  dest_base=$2
  shift 2
  mkdir -p "$dest_base"
  for file in "$@"; do
    if [[ ! -f "$dest_base/$file" ]]; then
      wget \
        --no-verbose \
        --show-progress \
        -O "$dest_base/$file" \
        "$url_base/$file"
    else
      echo "Already downloaded: $file"
    fi
  done
}

download_directories() {
  local url_base dest_base cut_dirs dir
  if [[ $# -lt 3 ]]; then
    exit 1
  fi
  url_base=$1
  dest_base=$2
  shift 2
  mkdir -p "$dest_base"
  cut_dirs=$(url_path_depth "$url_base")
  for dir in "$@"; do
    if [[ ! -d "$dest_base/$dir" ]]; then
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
      echo "Already downloaded: $dir"
    fi
  done
}

download_slackware() {
  local slack_base
  if [[ $# -ne 1 ]]; then
    exit 1
  fi
  slack_base=$PWD
  if [[ ! -d "$slack_base/slackware-$1" ]]; then
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
    echo "Already downloaded: slackware-$1"
  fi
}

download_debian() {
  local debian_base rel_base rel_url files dirs
  if [[ $# -ne 1 ]]; then
    exit 1
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
    hamm|slink|potato|woody)
      dirs=("binary-i386" "disks-i386")
      ;;
    *)
      dirs=("binary-i386" "installer-i386")
      ;;
  esac
  download_files "$rel_url" "$rel_base" "${files[@]}"
  download_directories "$rel_url" "$rel_base" "${dirs[@]}"
}

download_all() {
  local cdrom cdrom_dir cdrom_download file ver rel
  mkdir -p "$2"
  if [[ -f $1/cdrom.txt ]]; then
    cdrom=$(<"$1/cdrom.txt")
    cdrom_dir=$(cd "$SCRIPTDIR/cdrom/$cdrom" && pwd)
    cdrom_download=$cdrom_dir/.download
    download_all "$cdrom_dir" "$cdrom_download"
    for file in "$cdrom_download"/*; do
      if [[ -e "$file" ]]; then
        ln -sf "$file" "$2"
      fi
    done
  fi
  if [[ -f "$1/download.txt" ]]; then
    download_list "$1/download.txt" "$2"
  fi
  if [[ -f "$1/slackmirror.txt" ]]; then
    ver=$(<"$1/slackmirror.txt")
    (cd "$2" || exit; download_slackware "$ver")
  fi
  if [[ -f "$1/debmirror.txt" ]]; then
    rel=$(<"$1/debmirror.txt")
    (cd "$2" || exit; download_debian "$rel")
  fi
  if [[ -f "$1/download.sh" ]]; then
    pushd "$2" > /dev/null || return
    # shellcheck source=/dev/null
    source "$1/download.sh"
    popd > /dev/null || return
  fi
}

retro_download() {
  download_all "$CONFDIR" "$ORIGDIR"
}
