# shellcheck shell=bash
# Generic autoinstall staging and patching helpers shared by supported distros.

# Patches the extracted boot or root image so it runs the autoinst entrypoint.
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

# Stages the shared and distro-specific autoinstall files on the FAT media.
autoinst_prep() {
  local autoinst_d=$EXTRACTDIR/fat/autoinst.d
  local autoinst_file autoconf_file
  cp "$AUTOBASE/autoinst.sh" "$EXTRACTDIR/fat/autoinst"
  rm -rf "$autoinst_d"
  mkdir -p "$autoinst_d"
  cp -R "$AUTOBASE"/. "$autoinst_d"
  mkdir -p "$autoinst_d/distro"
  if autoinst_file=$(retro_config_file autoinst.sh); then
    cp "$autoinst_file" "$autoinst_d/distro/autoinst.sh"
  fi
  if autoconf_file=$(retro_config_file autoconf.sh); then
    cp "$autoconf_file" "$autoinst_d/distro/autoconf.sh"
  fi
  slackware_prepare_tagfiles
}
