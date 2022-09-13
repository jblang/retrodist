#!/usr/bin/env bash
if [[ ! -f hda.img ]]; then
  qemu-img create -f qcow2 hda.img 500M
fi
if [[ ! -d hdb ]]; then
  cp -R $CACHE hdb
  cp -LR $CONF/../_autoinst/* hdb
fi
if [[ ! -f fda.img ]]; then
  mv hdb/boot.img fda.img
fi