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

mount_copy() {
  echo "Using sudo to mount $(basename $1); enter your password if prompted."
  sudo mount -o ro $1 /mnt
  if [[ $? ]]; then
    sudo cp -R --preserve=timestamp "/mnt" $2
    sudo umount /mnt
    sudo chown -R $USER:$USER $2
    chmod -R ugo+r $2
    chmod -R u+w $2
    chmod -R go-w $2
    find $2 -type d | xargs chmod ugo+x
  fi
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