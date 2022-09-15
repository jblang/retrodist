#!/usr/bin/env bash
SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPTDIR/common.sh

if [[ $# -ne 1 ]]; then
  echo "Usage $(basename $0) conf"
  exit 1
fi
NAME=$1

# for distros that are sourced from elsewhere
CONFDIR=$PWD/$NAME
if [[ -f $CONFDIR/source.txt ]]; then
  SOURCE=$(cat $CONFDIR/source.txt)
  ORIGDIR=$ORIGBASE/$SOURCE
else
  ORIGDIR=$ORIGBASE/$NAME
fi
CACHEDIR="$CACHEBASE/$NAME"
if [[ ! -d $CACHEDIR ]]; then
  $SCRIPTDIR/download.sh $NAME
  mkdir -p $CACHEDIR
  cd $CACHEDIR
  if [[ -f "$CONFDIR/extract.sh" ]]; then
    source "$CONFDIR/extract.sh"
  else
    FILES=$ORIGDIR/*
    if [[ $FILES == "$ORIGDIR/*" ]]; then
      echo "Nothing to extract for $NAME"
      exit
    fi
    for FILE in $FILES; do
      BASE=$(basename $FILE)
      echo "Extracting $BASE"
      for EXT in .iso .zip .tar.gz; do
        BASE=$(basename $BASE $EXT)
      done
      DEST="$CACHEDIR/$BASE"
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
  echo "Using cached files in $CACHEDIR."
fi