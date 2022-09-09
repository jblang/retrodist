#!/usr/bin/env bash
SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPTDIR/common.sh

if [[ $# -ne 1 ]]; then
  echo "Usage $(basename $0) conf"
  exit 1
fi

ORIG="$ORIGBASE/$1"
CACHE="$CACHEBASE/$1"
if [[ ! -d $CACHE ]]; then
  $SCRIPTDIR/download.sh $1
  mkdir -p $CACHE
  if [[ -f "$1/extract.sh" ]]; then
    source "$1/extract.sh"
  else
    FILES=$ORIG/*
    if [[ -z $FILES ]]; then
      echo "No files to extract for $1"
      exit 1
    fi
    for FILE in $FILES; do
      BASE=$(basename $FILE)
      echo "Extracting $BASE"
      for EXT in .iso .zip .tar.gz; do
        BASE=$(basename $FILE $EXT)
      done
      DEST="$CACHE/$BASE"
      if [[ ! -f "$DEST" ]]; then
        if [[ $FILE = *.iso ]]; then
          if ! mount_copy "$FILE" "$DEST"; then
            echo "Error extracting $FILE."
          fi
        elif [[ $FILE == *.zip ]]; then
          unzip -q $FILE -d $DEST
        elif [[ $FILE == *.tar* ]]; then
          tar xf $FILE -C $DEST
        else
          echo "Don't know how to extract $FILE."
        fi
      else
        echo "Skipping $(basename $FILE) (already extracted)"
      fi
    done
  fi
else
  echo "Using cached files in $CACHE."
fi