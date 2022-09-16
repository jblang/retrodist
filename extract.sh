#!/usr/bin/env bash
SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPTDIR/common.sh

# validate command line arguments
if [[ $# -ne 1 ]]; then
  echo "Usage: $(basename $0) conf"
  exit 1
fi
NAME=$1
CONFDIR=$PWD/$NAME
if [[ ! -d "$CONFDIR" ]]; then
  echo "$NAME configuration doesn't exist."
  exit 1
fi

# handle distros that are sourced from elsewhere
if [[ -f $CONFDIR/source.txt ]]; then
  SOURCE=$(cat $CONFDIR/source.txt)
else
  SOURCE=$NAME
fi

# perform distro-specific extraction
ORIGDIR=$ORIGBASE/$SOURCE
CACHEDIR="$CACHEBASE/$NAME"
if [[ ! -d $CACHEDIR ]]; then
  $SCRIPTDIR/download.sh $SOURCE
  if [[ -f "$CONFDIR/extract.sh" ]]; then
    mkdir -p $CACHEDIR
    cd $CACHEDIR
    source "$CONFDIR/extract.sh"
  fi

  # copy auto installation files if they exist
  if [[ -d "$CONFDIR/../_autoinst" ]]; then
    mkdir -p $CACHEDIR/install
    cp -LR $CONFDIR/../_autoinst/* $CACHEDIR/install
  fi
else
  echo "Using cached files in $CACHEDIR."
fi