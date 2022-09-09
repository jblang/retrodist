#!/usr/bin/env bash
if [[ ! -f hda.img ]]; then
  qemu-img create -f qcow2 hda.img 500M
fi
if [[ ! -d hdb ]]; then
  ls $CACHE
  cp -lR $CACHE hdb
  ln $CONF/../_custom/* hdb
fi
if [[ ! -f fda.img ]]; then
  mv hdb/a1.img fda.img
fi