# set up common environment variables and functions
set -euo pipefail
RETROHOME=${RETROHOME:-$SCRIPTDIR/.retro}

ORIGBASE=$RETROHOME/orig
CACHEBASE=$RETROHOME/cache
QEMUBASE=$RETROHOME/qemu
JUMPBASE=$RETROHOME/jump
SLACKBASE=$ORIGBASE/mirrors.slackware.com/slackware

TEMPDIR=$(mktemp -d)
trap 'rm -rf "$TEMPDIR"' EXIT

download_list() {
  cat $1 | while read FILE URL || [ "$FILE" ]; do
    DEST=$2/$FILE
    if [[ ! -f "$DEST" ]]; then
      echo "Downloading $FILE"
      wget --no-verbose --show-progress -O "$DEST" "$URL"
    else
      echo "Skipping $FILE (already exists)"
    fi
  done
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

mount_copy() {
  IMAGE=$1
  DEST=$2
  shift; shift
  echo "Using sudo to mount $(basename $IMAGE); enter your password if prompted."  
  sudo mount -o ro "$IMAGE" /mnt
  if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
      sudo cp -R --preserve=timestamp "/mnt/$1" "$DEST"
      fix_perms $DEST/$(basename $1)
      shift
    done
  else
    sudo cp -R --preserve=timestamp "/mnt" "$DEST"
    fix_perms $DEST
  fi
  sudo umount /mnt
}

slackware_mirror() {
  if [[ ! -d "$SLACKBASE/slackware-$1" ]]; then
    wget \
      --no-verbose \
      --show-progress \
      --recursive \
      --no-parent \
      --reject "*.md5*,*.meta4,*.sha*,*mirror*,*index*" \
      "http://mirrors.slackware.com/slackware/slackware-$1/"
  else
    echo "Skipping download of existing slackware-$1 files."
  fi
}