# shellcheck shell=bash
# Generic autoinstall staging and patching helpers shared by supported distros.

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
  local autoinst_d=$EXTRACTDIR/install/autoinst.d
  cp "$AUTOBASE/autoinst.sh" "$EXTRACTDIR/install/autoinst"
  cp -R "$AUTOBASE" "$autoinst_d"
  mkdir -p "$autoinst_d/distro"
  if [[ -f $CONFDIR/autoinst.sh ]]; then
    cp "$CONFDIR/autoinst.sh" "$autoinst_d/distro/autoinst.sh"
  fi
  if [[ -f $CONFDIR/autoconf.sh ]]; then
    cp "$CONFDIR/autoconf.sh" "$autoinst_d/distro/autoconf.sh"
  fi
  slackware_prepare_tagfiles
}
