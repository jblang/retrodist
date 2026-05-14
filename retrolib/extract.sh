# Extraction helpers for mounting media images and building the staged install tree.
retro_extract() {
  if [[ ! -d $EXTRACTDIR ]]; then
    retro_download
    if [[ -f "$CONFDIR/extract.sh" || -f "$CONFDIR/autoinst.sh" ]]; then
      mkdir -p $EXTRACTDIR
      pushd $EXTRACTDIR > /dev/null
      if [[ -f "$CONFDIR/extract.sh" ]]; then
        source "$CONFDIR/extract.sh"
      fi
      if [[ -f "$CONFDIR/autoinst.sh" ]]; then
        mkdir -p "$EXTRACTDIR/install"
        load_qemu_config
        autoinst_prep
      fi
      popd > /dev/null
    else
      echo "Nothing to extract"
    fi
  else
    echo "Using extracted files"
  fi
}
