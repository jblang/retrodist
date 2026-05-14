# Download helpers for mirrors, per-distro manifests, and recursive asset fetches.
download_list() {
  if [[ $# -ne 2 ]]; then
    exit 1
  fi
  cat_newline $1 | while read FILE URL; do
    DEST=$2/$FILE
    if [[ -n "$FILE" && -n "$URL" ]]; then
      if [[ ! -f "$DEST" ]]; then
        echo "Downloading $FILE"
        wget --no-verbose --show-progress -O "$DEST" "$URL"
      else
        echo "Already downloaded: $FILE"
      fi
    fi
  done
}

download_files() {
  if [[ $# -lt 3 ]]; then
    exit 1
  fi
  URLBASE=$1
  DESTBASE=$2
  shift 2
  mkdir -p "$DESTBASE"
  for FILE in "$@"; do
    if [[ ! -f "$DESTBASE/$FILE" ]]; then
      wget \
        --no-verbose \
        --show-progress \
        -O "$DESTBASE/$FILE" \
        "$URLBASE/$FILE"
    else
      echo "Already downloaded: $FILE"
    fi
  done
}

download_directories() {
  if [[ $# -lt 3 ]]; then
    exit 1
  fi
  URLBASE=$1
  DESTBASE=$2
  shift 2
  mkdir -p "$DESTBASE"
  local CUTDIRS=$(url_path_depth "$URLBASE")
  for DIR in "$@"; do
    if [[ ! -d "$DESTBASE/$DIR" ]]; then
      wget \
        --no-verbose \
        --show-progress \
        --recursive \
        --no-parent \
        --no-host-directories \
        --cut-dirs="$CUTDIRS" \
        --directory-prefix="$DESTBASE" \
        --reject "*index*" \
        "$URLBASE/$DIR/"
    else
      echo "Already downloaded: $DIR"
    fi
  done
}

download_slackware() {
  if [[ $# -ne 1 ]]; then
    exit 1
  fi
  local SLACKBASE=$PWD
  if [[ ! -d "$SLACKBASE/slackware-$1" ]]; then
    wget \
      --no-verbose \
      --show-progress \
      --recursive \
      --no-parent \
      --no-host-directories \
      --cut-dirs=1 \
      --directory-prefix="$SLACKBASE" \
      --reject "*.md5*,*.meta4,*.sha*,*mirror*,*index*" \
      "http://mirrors.slackware.com/slackware/slackware-$1/"
  else
    echo "Already downloaded: slackware-$1"
  fi
}

download_debian() {
  if [[ $# -ne 1 ]]; then
    exit 1
  fi
  local DEBIANBASE=$PWD
  RELBASE="$DEBIANBASE/$1"
  RELURL="https://archive.debian.org/debian/dists/$1"
  if [[ "$1" != "Debian-0.93R6" ]]; then
    RELBASE="$RELBASE/main"
    RELURL="$RELURL/main"
  fi
  FILES="Contents-i386.gz"
  case "$1" in
    Debian-0.93R6)
      FILES="README.DEBIAN Contents"
      DIRS="ms-dos disks"
      ;;
    buzz)
      FILES="README Contents"
      DIRS="msdos-i386 disks-i386"
      ;;
    rex)
      FILES="README Contents"
      DIRS="msdos-i386 disks-i386"
      ;;
    bo)
      FILES="README Contents-i386.gz"
      DIRS="msdos-i386 disks-i386"
      ;;
    hamm|slink|potato|woody)
      DIRS="binary-i386 disks-i386"
      ;;
    *)
      DIRS="binary-i386 installer-i386"
      ;;
  esac
  download_files "$RELURL" "$RELBASE" $FILES
  download_directories "$RELURL" "$RELBASE" $DIRS
}

download_all() {
  mkdir -p "$2"
  if [[ -f $1/cdrom.txt ]]; then
    CDROM=$(cat $1/cdrom.txt)
    CDROMDIR=$(cd "$SCRIPTDIR/cdrom/$CDROM" && pwd)
    CDROMDOWNLOAD=$CDROMDIR/.download
    download_all "$CDROMDIR" "$CDROMDOWNLOAD"
    for FILE in "$CDROMDOWNLOAD"/*; do
      if [[ -e "$FILE" ]]; then
        ln -sf "$FILE" "$2"
      fi
    done
  fi
  if [[ -f "$1/download.txt" ]]; then
    download_list "$1/download.txt" "$2"
  fi
  if [[ -f "$1/slackmirror.txt" ]]; then
    VER="$(cat "$1/slackmirror.txt")"
    (cd "$2"; download_slackware "$VER")
  fi
  if [[ -f "$1/debmirror.txt" ]]; then
    REL="$(cat "$1/debmirror.txt")"
    (cd "$2"; download_debian "$REL")
  fi
  if [[ -f "$1/download.sh" ]]; then
    pushd "$2" > /dev/null
    source "$1/download.sh"
    popd > /dev/null
  fi
}

retro_download() {
  download_all "$CONFDIR" "$ORIGDIR"
}
