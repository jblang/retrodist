# Generic autoinstall staging and patching helpers shared by supported distros.
copy_autoinst_tree() {
  local SUBDIR=$1
  find "$AUTOBASE/$SUBDIR" -type f | while read -r SRC; do
    local REL=${SRC#"$AUTOBASE"/}
    mkdir -p "$AUTOINSTD/$(dirname "$REL")"
    cp "$SRC" "$AUTOINSTD/$REL"
  done
}

autoinst_patch() {
  retro_extract
  if [[ -f $EXTRACTDIR/root.img ]]; then
    PATCHIMG=$EXTRACTDIR/root.img
  elif [ -f $EXTRACTDIR/boot.img ]; then
    PATCHIMG=$EXTRACTDIR/boot.img
  fi
  echo "Using sudo to patch $PATCHIMG..."
  sudo mount $PATCHIMG /mnt
  sudo cp $AUTOBASE/autoinst.sh /mnt
  sudo chmod +x /mnt/autoinst.sh
  sudo umount /mnt
}

autoinst_prep() {
  AUTOINSTD=$EXTRACTDIR/install/autoinst.d
  mkdir -p $AUTOINSTD/config
  cp "$AUTOBASE/autoinst.sh" "$EXTRACTDIR/install/autoinst"
  cp "$AUTOBASE/autoconf.sh" "$AUTOINSTD/autoconf.sh"
  for SUBDIR in common debian slakware; do
    if [[ -d $AUTOBASE/$SUBDIR ]]; then
      rm -rf "$AUTOINSTD/$SUBDIR"
      copy_autoinst_tree "$SUBDIR"
    fi
  done
  if [[ -f $CONFDIR/autoinst.sh ]]; then
    cp "$CONFDIR/autoinst.sh" "$AUTOINSTD/config/autoinst.sh"
  fi
  if [[ -f $CONFDIR/autoconf.sh ]]; then
    cp "$CONFDIR/autoconf.sh" "$AUTOINSTD/config/autoconf.sh"
  fi
  slackware_prepare_tagfiles
}
