#!/usr/bin/env bash
if [[ ! -f hda.img ]]; then
  qemu-img create -f qcow2 hda.img 500M
fi
if [[ ! -d hdb ]]; then
  ln -s $CACHEDIR/install hdb
  if [[ -d "$CONFDIR/../_autoinst" ]]; then
    cp -LR $CONFDIR/../_autoinst/* hdb
  fi
fi
if [[ ! -f fda.img ]]; then
  ln -sr $CACHEDIR/boot.img fda.img
fi
if [[ -f $CACHEDIR/root.img && ! -f fdb.img ]]; then
  ln -sr $CACHEDIR/root.img .
fi