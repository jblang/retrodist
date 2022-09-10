#!/usr/bin/env bash
SCRIPTDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPTDIR/common.sh

if [[ $# -ne 1 ]]; then
  echo "Usage $(basename $0) conf"
  exit 1
fi

ORIG="$ORIGBASE/$1"
if [[ -f "$1/download.sh" ]]; then
  mkdir -p $ORIG
  SCRIPT=$PWD/$1/download.sh
  (cd $ORIG; source "$SCRIPT")
elif [[ -f "$1/urls.txt" ]]; then
  mkdir -p $ORIG
  download_list "$1/urls.txt" "$ORIG"
elif [[ -f "$1/slackver.txt" ]]; then
  mkdir -p $ORIG
  VER="$(cat "$1/slackver.txt")"
  (cd $ORIGBASE; slackware_mirror $VER)
else
  echo "Nothing to download for $1"
fi