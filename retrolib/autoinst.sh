# shellcheck shell=bash
# Generic autoinstall staging and patching helpers shared by supported distros.
copy_autoinst_tree() {
  local subdir=$1
  find "$AUTOBASE/$subdir" -type f | while IFS= read -r src; do
    local rel=${src#"$AUTOBASE"/}
    mkdir -p "$AUTOINSTD/$(dirname "$rel")"
    cp "$src" "$AUTOINSTD/$rel"
  done
}

autoinst_patch() {
  local patchimg=
  retro_extract
  if [[ -f $EXTRACTDIR/root.img ]]; then
    patchimg=$EXTRACTDIR/root.img
  elif [[ -f $EXTRACTDIR/boot.img ]]; then
    patchimg=$EXTRACTDIR/boot.img
  fi
  echo "Using sudo to patch $patchimg..."
  sudo mount "$patchimg" /mnt
  sudo cp "$AUTOBASE/autoinst.sh" /mnt
  sudo chmod +x /mnt/autoinst.sh
  sudo umount /mnt
}

autoinst_prep() {
  local subdir
  AUTOINSTD=$EXTRACTDIR/install/autoinst.d
  mkdir -p "$AUTOINSTD/config"
  cp "$AUTOBASE/autoinst.sh" "$EXTRACTDIR/install/autoinst"
  cp "$AUTOBASE/autoconf.sh" "$AUTOINSTD/autoconf.sh"
  for subdir in common debian slakware slackware sls; do
    if [[ -d "$AUTOBASE/$subdir" ]]; then
      rm -rf "${AUTOINSTD:?}/$subdir"
      copy_autoinst_tree "$subdir"
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
